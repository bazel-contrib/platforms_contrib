load("@rules_shell//shell:sh_binary.bzl", "sh_binary")

FooToolchainInfo = provider(
    doc = "Foo toolchain.",
    fields = {
        "binary": "FilesToRun for an executable that prints a fixed text.",
    },
)

_TOOLCHAIN_TYPE = Label("//rules/foo:toolchain_type")

def _foo_script_impl(ctx):
    out = ctx.actions.declare_file(ctx.label.name + ".sh")
    ctx.actions.write(
        output = out,
        content = '#!/bin/sh\necho "{}"\n'.format(ctx.attr.text),
        is_executable = True,
    )
    return [DefaultInfo(files = depset([out]))]

_foo_script = rule(
    implementation = _foo_script_impl,
    attrs = {"text": attr.string(mandatory = True)},
)

def _foo_toolchain_info_impl(ctx):
    return [
        DefaultInfo(files = ctx.attr.binary[DefaultInfo].files),
        platform_common.ToolchainInfo(
            foo_info = FooToolchainInfo(
                binary = ctx.attr.binary[DefaultInfo].files_to_run,
            ),
        ),
        platform_common.TemplateVariableInfo({
            "FOO": ctx.attr.binary[DefaultInfo].files_to_run.executable.path,
        }),
    ]

_foo_toolchain_info = rule(
    implementation = _foo_toolchain_info_impl,
    attrs = {
        "binary": attr.label(
            mandatory = True,
            executable = True,
            cfg = "exec",
        ),
    },
)

def foo_toolchain(
        name,
        text,
        target_compatible_with = None,
        exec_compatible_with = None,
        **kwargs):
    _foo_script(
        name = name + "_script",
        text = text,
    )
    sh_binary(
        name = name + "_bin",
        srcs = [name + "_script"],
    )
    _foo_toolchain_info(
        name = name + "_info",
        binary = name + "_bin",
    )
    native.toolchain(
        name = name,
        toolchain = name + "_info",
        toolchain_type = _TOOLCHAIN_TYPE,
        target_compatible_with = target_compatible_with,
        exec_compatible_with = exec_compatible_with,
        **kwargs
    )

def _target_platform_transition_impl(_, attr):
    if attr.target_platform == None:
        return {}
    return {"//command_line_option:platforms": [attr.target_platform]}

_target_platform_transition = transition(
    implementation = _target_platform_transition_impl,
    inputs = ["//command_line_option:platforms"],
    outputs = ["//command_line_option:platforms"],
)

def _foo_binary_impl(ctx):
    toolchain = ctx.toolchains[_TOOLCHAIN_TYPE].foo_info
    out = ctx.actions.declare_file(ctx.label.name + ".sh")
    ctx.actions.run_shell(
        outputs = [out],
        tools = [toolchain.binary],
        command = """set -e
text=$("$1")
{
  echo '#!/bin/sh'
  echo "echo \\"$text\\""
} > "$2"
chmod +x "$2"
""",
        arguments = [toolchain.binary.executable.path, out.path],
    )
    return [DefaultInfo(
        executable = out,
        files = depset([out]),
    )]

foo_binary = rule(
    implementation = _foo_binary_impl,
    executable = True,
    cfg = _target_platform_transition,
    attrs = {
        "target_platform": attr.label(),
    },
    toolchains = [_TOOLCHAIN_TYPE],
)
