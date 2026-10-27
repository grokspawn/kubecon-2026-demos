# Demo 2 content: an operator whose deployment requires a ConfigMap that
# the demo deliberately does not create up front. The pod stays in
# CreateContainerConfigError, the owning ClusterObjectSet phase cannot
# stabilize, and the ClusterExtension reports blocked progress with
# per-object detail. Creating the ConfigMap unblocks the rollout.
#
# Package: kubecon-rollout-operator v0.2.0 (separate from demo 1's package
# so each demo installs independently).
