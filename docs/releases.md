# Releases

A release records exact component revisions, dependency order, validation
evidence, migration requirements, and rollback instructions. The workspace has
no implicit remote release target.

Prepare changes on `main`, review the concrete diff, and obtain direct approval
before making separate atomic commits in each repository. Publication is a
separate explicit approval. A production deployment requires additional
authorization and the safeguards in [deployment.md](deployment.md).
