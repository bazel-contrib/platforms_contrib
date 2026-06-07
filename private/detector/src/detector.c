/*
 * Host detection helper for @platforms_contrib//host.
 *
 * Writes one repo-relative label per line on stdout. Each line names the
 * `at_least_<detected_version>_available` constraint_value for a libc
 * family found installed on the host. Empty lines and lines starting
 * with '#' are reserved for comments and ignored by the consuming
 * repository rule.
 *
 * Each supported libc family is probed independently: both can be
 * installed on the same machine (e.g. a Debian system with musl-tools)
 * and the constraint set is additive. The detector deliberately makes
 * no attempt to identify "the" libc.
 *
 * The detector also deliberately does NOT know the set of constraint
 * values that actually exist in @platforms_contrib. It emits the raw
 * detected version; the repo rule loads the version range constants
 * and clips to the highest supported value.
 *
 * Possible labels (zero, one, or both per run):
 *   //os/linux/libc/glibc:at_least_<major>.<minor>_available
 *   //os/linux/libc/musl:at_least_<major>.<minor>_available
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

static int file_exists(const char *path) {
    return access(path, F_OK) == 0;
}

/*
 * Forks and executes `path` with the given argv, capturing both stdout
 * and stderr in `out`. Returns the number of bytes written (always
 * NUL-terminated), or -1 on failure.
 */
static ssize_t capture_output(const char *path, char *const argv[],
                              char *out, size_t out_size) {
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
        if (dup2(pipefd[1], STDERR_FILENO) < 0) _exit(127);
        close(pipefd[1]);
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
static int detect_glibc_version(int *major_out, int *minor_out) {
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
    ssize_t n = capture_output(libc, argv, buf, sizeof(buf));
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
    if (sscanf(last, "%d.%d", &major, &minor) != 2 || major != 2) return 0;
    *major_out = major;
    *minor_out = minor;
    return 1;
}

/*
 * musl's dynamic linker is executable too: running it prints
 *   musl libc (x86_64)
 *   Version 1.2.5
 *   ...
 * on stderr (older releases) or stdout (newer releases). capture_output
 * merges both streams, so we just scan for the "Version " token.
 */
static int detect_musl_version(int *major_out, int *minor_out) {
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

    char buf[1024];
    char *const argv[] = { (char *)ld, NULL };
    ssize_t n = capture_output(ld, argv, buf, sizeof(buf));
    if (n <= 0) return 0;

    const char *p = strstr(buf, "Version ");
    if (p == NULL) return 0;
    p += strlen("Version ");

    int major = 0, minor = 0;
    if (sscanf(p, "%d.%d", &major, &minor) != 2) return 0;
    *major_out = major;
    *minor_out = minor;
    return 1;
}

#endif /* __linux__ */

int main(void) {
#if defined(__linux__)
    int major = 0, minor = 0;
    if (detect_glibc_version(&major, &minor)) {
        printf("//os/linux/libc/glibc:at_least_%d.%d_available\n",
               major, minor);
    }
    if (detect_musl_version(&major, &minor)) {
        printf("//os/linux/libc/musl:at_least_%d.%d_available\n",
               major, minor);
    }
#endif
    return 0;
}
