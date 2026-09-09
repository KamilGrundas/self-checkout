# Data refresh

Data refresh is a controlled, one-way operation from production to development.
It is not part of routine development and is not implemented by a remote-copy
workflow in this workspace.

A requested refresh must name the source and target, prove that the target is
the isolated DEV environment, and include a reviewed backup/restore and
verification plan. Never copy production environment files, credentials, private
keys, or host configuration. Never send DEV data to production.
