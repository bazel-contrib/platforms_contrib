/*
 * Host detection helper for @platforms_contrib//host.
 *
 * Writes one repo-relative label per line on stdout. Each line names a
 * constraint_value in @platforms_contrib that the host satisfies but that
 * cannot be inferred from compile-time configuration alone. Empty lines and
 * lines starting with '#' are reserved for comments and ignored by the
 * consuming repository rule.
 *
 * Possible labels:
 *   //os/linux/libc/glibc:at_least_2.XY_available  (Linux, glibc)
 *   //os/linux/libc/musl:at_least_1.X_available    (Linux, musl)
 *
 * The detector is intentionally Linux-only — every other host platform
 * configuration is already known at compile time. On other operating
 * systems main() exits cleanly with no output and the repository rule
 * generates an empty constraint list.
 *
 * The binary must be self-contained: it is shipped as a prebuilt artifact
 * and may be executed on systems whose libc it was not linked against. On
 * Linux it is therefore built fully statically against musl, and it never
 * assumes that its own libc matches the host's.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#if defined(__linux__)
#  include <errno.h>
#  include <fcntl.h>
#  include <sys/types.h>
#  include <sys/wait.h>
#  include <unistd.h>
#endif

#if defined(__linux__)

/*
 * Supported version ranges. Must stay in sync with GLIBC_VERSIONS and
 * MUSL_VERSIONS in os/linux/libc/{glibc,musl}/{glibc,musl}_private.bzl.
 *
 * Versions are kept as (major, minor) tuples to avoid string handling in
 * range comparisons. When the host advertises a version newer than the
 * range, output saturates at the highest supported entry — the resulting
 * constraint accurately reflects the lower bound that's guaranteed.
 */
#define GLIBC_MAJOR    2
#define GLIBC_MIN_MINOR 15
#define GLIBC_MAX_MINOR 45

#define MUSL_MAJOR     1
#define MUSL_MIN_MINOR 0
#define MUSL_MAX_MINOR 2

static int file_exists(const char *path) {
    return access(path, F_OK) == 0;
}

/* Returns "glibc" | "musl" | NULL. */
static const char *detect_linux_libc(void) {
    static const char *const musl_paths[] = {
        "/lib/ld-musl-x86_64.so.1",
        "/lib/ld-musl-aarch64.so.1",
        "/lib/ld-musl-armhf.so.1",
        "/lib/ld-musl-arm.so.1",
        "/lib/ld-musl-i386.so.1",
        "/lib/ld-musl-riscv64.so.1",
        NULL,
    };
    for (int i = 0; musl_paths[i] != NULL; i++) {
        if (file_exists(musl_paths[i])) return "musl";
    }

    static const char *const glibc_paths[] = {
        "/lib64/ld-linux-x86-64.so.2",
        "/lib/ld-linux-aarch64.so.1",
        "/lib/ld-linux-armhf.so.3",
        "/lib/ld-linux.so.2",
        "/lib64/ld-linux-riscv64-lp64d.so.1",
        NULL,
    };
    for (int i = 0; glibc_paths[i] != NULL; i++) {
        if (file_exists(glibc_paths[i])) return "glibc";
    }

    return NULL;
}

/*
 * Forks and executes `path` with the given argv, capturing the first
 * ~1 KiB of stdout. Returns the number of bytes captured into `out` (which
 * is always NUL-terminated). Returns -1 on failure to fork/pipe.
 *
 * stderr is redirected to /dev/null because some versions of musl print
 * usage information there even on a clean invocation.
 */
static ssize_t capture_stdout(const char *path,
                              char *const argv[],
                              char *out,
                              size_t out_size) {
    if (out_size == 0) return -1;

    int pipefd[2];
    if (pipe(pipefd) != 0) return -1;

    pid_t pid = fork();
    if (pid < 0) {
        close(pipefd[0]);
        close(pipefd[1]);
        return -1;
    }
    if (pid == 0) {
        close(pipefd[0]);
        if (dup2(pipefd[1], STDOUT_FILENO) < 0) _exit(127);
        close(pipefd[1]);
        int devnull = open("/dev/null", O_WRONLY);
        if (devnull >= 0) {
            dup2(devnull, STDERR_FILENO);
            close(devnull);
        }
        char *const envp[] = { NULL };
        execve(path, argv, envp);
        _exit(127);
    }
    close(pipefd[1]);

    size_t total = 0;
    for (;;) {
        if (total >= out_size - 1) break;
        ssize_t n = read(pipefd[0], out + total, out_size - 1 - total);
        if (n > 0) { total += (size_t)n; continue; }
        if (n < 0) {
            if (errno == EINTR) continue;
            break;
        }
        break; /* EOF */
    }
    close(pipefd[0]);
    int status = 0;
    waitpid(pid, &status, 0);

    out[total] = '\0';
    return (ssize_t)total;
}

/*
 * glibc's libc.so.6 is itself executable: running it prints version info,
 * whose first line ends with " version 2.NN.".
 */
static int detect_glibc_minor(int *minor_out) {
    static const char *const candidates[] = {
        "/lib/x86_64-linux-gnu/libc.so.6",
        "/lib/aarch64-linux-gnu/libc.so.6",
        "/lib/arm-linux-gnueabihf/libc.so.6",
        "/lib/i386-linux-gnu/libc.so.6",
        "/lib/riscv64-linux-gnu/libc.so.6",
        "/lib64/libc.so.6",
        "/lib/libc.so.6",
        "/usr/lib/libc.so.6",
        NULL,
    };
    const char *libc = NULL;
    for (int i = 0; candidates[i] != NULL; i++) {
        if (file_exists(candidates[i])) { libc = candidates[i]; break; }
    }
    if (libc == NULL) return 0;

    char buf[1024];
    char *const argv[] = { (char *)libc, NULL };
    ssize_t n = capture_stdout(libc, argv, buf, sizeof(buf));
    if (n <= 0) return 0;

    char *nl = strchr(buf, '\n');
    if (nl != NULL) *nl = '\0';

    /* Find the LAST " 2." token followed by digits in the first line. */
    const char *last = NULL;
    for (const char *p = buf; (p = strstr(p, " 2.")) != NULL; p += 1) {
        last = p + 1;
    }
    if (last == NULL) return 0;

    int major = 0, minor = 0;
    if (sscanf(last, "%d.%d", &major, &minor) != 2 || major != GLIBC_MAJOR) return 0;
    *minor_out = minor;
    return 1;
}

/*
 * musl's dynamic linker is executable too: running it prints
 *   musl libc (x86_64)
 *   Version 1.2.5
 *   ...
 * on stderr (older releases) or stdout (newer releases). We capture both
 * by routing stderr→stdout in the child if needed; for simplicity here we
 * just re-pipe stderr along with stdout.
 */
static int detect_musl_minor(int *minor_out) {
    static const char *const candidates[] = {
        "/lib/ld-musl-x86_64.so.1",
        "/lib/ld-musl-aarch64.so.1",
        "/lib/ld-musl-armhf.so.1",
        "/lib/ld-musl-arm.so.1",
        "/lib/ld-musl-i386.so.1",
        "/lib/ld-musl-riscv64.so.1",
        NULL,
    };
    const char *ld = NULL;
    for (int i = 0; candidates[i] != NULL; i++) {
        if (file_exists(candidates[i])) { ld = candidates[i]; break; }
    }
    if (ld == NULL) return 0;

    /*
     * musl writes its banner to stderr. Fork a child that routes stderr to
     * the read pipe, then capture.
     */
    int pipefd[2];
    if (pipe(pipefd) != 0) return 0;

    pid_t pid = fork();
    if (pid < 0) {
        close(pipefd[0]);
        close(pipefd[1]);
        return 0;
    }
    if (pid == 0) {
        close(pipefd[0]);
        if (dup2(pipefd[1], STDOUT_FILENO) < 0) _exit(127);
        if (dup2(pipefd[1], STDERR_FILENO) < 0) _exit(127);
        close(pipefd[1]);
        char *const argv[] = { (char *)ld, NULL };
        char *const envp[] = { NULL };
        execve(ld, argv, envp);
        _exit(127);
    }
    close(pipefd[1]);

    char buf[1024];
    size_t total = 0;
    for (;;) {
        if (total >= sizeof(buf) - 1) break;
        ssize_t n = read(pipefd[0], buf + total, sizeof(buf) - 1 - total);
        if (n > 0) { total += (size_t)n; continue; }
        if (n < 0) {
            if (errno == EINTR) continue;
            break;
        }
        break;
    }
    close(pipefd[0]);
    int status = 0;
    waitpid(pid, &status, 0);

    if (total == 0) return 0;
    buf[total] = '\0';

    /*
     * Look for "Version " followed by "1.X" and pull out the minor. We scan
     * for the literal because musl's exact line ordering varies between
     * versions.
     */
    const char *p = strstr(buf, "Version ");
    if (p == NULL) return 0;
    p += strlen("Version ");

    int major = 0, minor = 0;
    if (sscanf(p, "%d.%d", &major, &minor) != 2 || major != MUSL_MAJOR) return 0;
    *minor_out = minor;
    return 1;
}

static void emit_at_least(const char *pkg, int major, int from_minor,
                          int to_minor, int detected_minor) {
    int last = detected_minor;
    if (last > to_minor) last = to_minor;
    for (int m = from_minor; m <= last; m++) {
        printf("//os/linux/libc/%s:at_least_%d.%d_available\n", pkg, major, m);
    }
}

#endif /* __linux__ */

int main(void) {
#if defined(__linux__)
    const char *libc = detect_linux_libc();
    if (libc == NULL) return 0;

    if (strcmp(libc, "glibc") == 0) {
        int minor = 0;
        if (detect_glibc_minor(&minor) && minor >= GLIBC_MIN_MINOR) {
            emit_at_least("glibc", GLIBC_MAJOR, GLIBC_MIN_MINOR,
                          GLIBC_MAX_MINOR, minor);
        }
    } else if (strcmp(libc, "musl") == 0) {
        int minor = 0;
        if (detect_musl_minor(&minor) && minor >= MUSL_MIN_MINOR) {
            emit_at_least("musl", MUSL_MAJOR, MUSL_MIN_MINOR,
                          MUSL_MAX_MINOR, minor);
        }
    }
#endif
    return 0;
}
