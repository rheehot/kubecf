load("@bazel_skylib//lib:paths.bzl", "paths")
load("//:def.bzl", "project")

def _kind_impl(ctx):
    metrics_server_dir = None
    for f in ctx.files._metrics_server:
        dir = paths.dirname(f.path)
        if metrics_server_dir == None:
            metrics_server_dir = dir
        else:
            if dir != metrics_server_dir:
                print("{} != {}".format(dir, metrics_server_dir))
                fail("multiple directories are not supported for the metrics-server")

    executable = ctx.actions.declare_file(ctx.attr.name)
    contents = """
        set -o errexit
        export KIND="{kind}"
        export CLUSTER_NAME="{cluster_name}"
        export KUBECTL="{kubectl}"
        export METRICS_SERVER="{metrics_server}"
        export K8S_VERSION="${{K8S_VERSION:-{k8s_version}}}"
        export LOCAL_PATH_STORAGE_YAML="{local_path_storage_yaml}"
        export KUBE_DASHBOARD_YAML="{kube_dashboard}"
        "{script}"
    """.format(
        kind = ctx.executable._kind.short_path,
        cluster_name = ctx.attr.cluster_name,
        kubectl = ctx.executable._kubectl.short_path,
        metrics_server = metrics_server_dir,
        k8s_version = ctx.attr.k8s_version,
        local_path_storage_yaml = ctx.file._local_path_storage_yaml.short_path,
        kube_dashboard = ctx.file._kube_dashboard.short_path,
        script = ctx.executable._script.path,
    )
    ctx.actions.write(executable, contents, is_executable = True)
    runfiles = [
        ctx.executable._kind,
        ctx.executable._kubectl,
        ctx.executable._script,
        ctx.file._local_path_storage_yaml,
        ctx.file._kube_dashboard,
    ] + ctx.files._metrics_server
    return [DefaultInfo(
        executable = executable,
        runfiles = ctx.runfiles(files = runfiles),
    )]

attrs = {
    "cluster_name": attr.string(
        mandatory = True,
    ),
    "k8s_version": attr.string(
        default = "v{}".format(project.kubernetes.version),
    ),
    "_kind": attr.label(
        allow_single_file = True,
        cfg = "host",
        default = "@kind//:binary",
        executable = True,
    ),
    "_kubectl": attr.label(
        allow_single_file = True,
        cfg = "host",
        default = "@kubectl//:binary",
        executable = True,
    ),
    "_metrics_server": attr.label(
        default = "@com_github_kubernetes_incubator_metrics_server//:deploy",
        allow_files = True,
    ),
    "_local_path_storage_yaml": attr.label(
        default = "@local_path_provisioner//file",
        allow_single_file = True,
    ),
    "_kube_dashboard": attr.label(
        default = "@kube_dashboard//file",
        allow_single_file = True,
    ),
}

kind_start_binary = rule(
    implementation = _kind_impl,
    attrs = dict({
        "_script": attr.label(
            allow_single_file = True,
            cfg = "host",
            default = "//dev/kind:start.sh",
            executable = True,
        )
    }, **attrs),
    executable = True,
)

kind_delete_binary = rule(
    implementation = _kind_impl,
    attrs = dict({
        "_script": attr.label(
            allow_single_file = True,
            cfg = "host",
            default = "//dev/kind:delete.sh",
            executable = True,
        )
    }, **attrs),
    executable = True,
)
