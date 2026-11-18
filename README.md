<!-- SPDX-License-Identifier: MPL-2.0 -->

# terraform-provider-awscognito (UNOFFICIAL, temporary fork)

> **This is not the official AWS provider.** It is an unofficial, temporary fork of
> [hashicorp/terraform-provider-aws](https://github.com/hashicorp/terraform-provider-aws)
> and is not affiliated with or endorsed by HashiCorp, IBM or AWS.
> It will be **archived** as soon as the change below is released upstream.

Registry address: `majkel-hyggio/awscognito`.

## What it is

| | |
|---|---|
| Upstream base | `hashicorp/terraform-provider-aws` tag [`v6.54.0`](https://github.com/hashicorp/terraform-provider-aws/tree/v6.54.0), commit `8ca5b8dac50747f51e02a122d058f6eebd58ba19` |
| Only change | [PR #48388](https://github.com/hashicorp/terraform-provider-aws/pull/48388) (fixes [issue #47598](https://github.com/hashicorp/terraform-provider-aws/issues/47598)) by tabito-hara, diff `7c12155..3b355c5` (head `3b355c5422895511ac24509c4cb66bbe57d02a07`) |
| Effect | `aws_cognito_user_pool`: new argument `web_authn_configuration.factor_configuration` (`SINGLE_FACTOR` or `MULTI_FACTOR_WITH_USER_VERIFICATION`), needed to use passkeys as MFA |
| Fork version | `6.54.0` = version of the upstream base |

Everything else, including every other resource, the schema versions, `go.mod`/`go.sum`
and the AWS SDK versions, is byte-for-byte upstream `v6.54.0`.

## What differs from upstream `v6.54.0`

Commits on the default branch `hyggio/v6.54.0`:

1. `Import upstream hashicorp/terraform-provider-aws v6.54.0 (8ca5b8d)`: the unmodified upstream tree (no upstream history).
2. `Apply hashicorp/terraform-provider-aws PR #48388 (head 3b355c5)`: exactly the PR diff, 4 files, +91/-1:
   - `internal/service/cognitoidp/user_pool.go`
   - `internal/service/cognitoidp/user_pool_test.go`
   - `website/docs/r/cognito_user_pool.html.markdown`
   - `.changelog/48388.txt`
3. Release tooling (not provider code):
   - all upstream GitHub Actions workflows, composite actions and `dependabot.yml` removed, so nothing upstream runs in this repository;
   - `.github/workflows/release.yml`: the only workflow, triggered only by pushing a `v*` tag;
   - `.github/scripts/check-provenance.sh`: provenance check, see below;
   - `.goreleaser.yml`;
   - this `README.md` (replaces the upstream README).

The Go module path (`github.com/hashicorp/terraform-provider-aws`) and the debug-mode
address in `main.go` are unchanged on purpose, to keep the diff limited to the PR.

### Provenance check

Before every release the workflow runs `.github/scripts/check-provenance.sh`. It fetches
the pinned upstream tag and the pinned PR commits, rebuilds the tree
`upstream v6.54.0 + PR #48388` and compares it with the tag being released. Any difference
outside `.github/**`, `.goreleaser.yml` and `README.md` fails the release. You can run it
yourself on a clone of this repository:

```sh
bash .github/scripts/check-provenance.sh v6.54.0
```

## Usage

```hcl
terraform {
  required_providers {
    aws        = { source = "hashicorp/aws", version = "6.54.0" }
    awscognito = { source = "majkel-hyggio/awscognito", version = "6.54.0" }
  }
}

provider "awscognito" {
  region = "eu-central-1"
}

resource "aws_cognito_user_pool" "this" {
  provider = awscognito
  # ...
  web_authn_configuration {
    relying_party_id     = "example.auth.eu-central-1.amazoncognito.com"
    user_verification    = "required"
    factor_configuration = "MULTI_FACTOR_WITH_USER_VERIFICATION"
  }
}
```

Resource types keep their upstream names (`aws_*`). Use the fork only for the resources
that need the new argument and keep `hashicorp/aws` for everything else.
With a module, pass it as `providers = { aws = awscognito }`; the module must declare
`source = "majkel-hyggio/awscognito"` for its `aws` provider (see
[majkel-hyggio/terraform-aws-cognito-user-pool](https://github.com/majkel-hyggio/terraform-aws-cognito-user-pool)).

## Platforms

Releases contain only `linux_amd64` and `windows_amd64`. `terraform init` fails on other
platforms.

## Releases

- Tags `vX.Y.Z` use the version of the upstream base (`v6.54.0`). A released version is
  never replaced. If the same base has to be released again, the next free patch version
  is used and recorded here.
- Releases are built by GitHub Actions with GoReleaser from the public tag, after the
  provenance check and a manual approval in the `release` environment. `SHA256SUMS` is
  signed with the GPG key registered for the `majkel-hyggio` namespace in the
  Terraform Registry.

| Fork tag | Upstream base | PR #48388 head |
|---|---|---|
| `v6.54.0` (not released yet) | `v6.54.0` (`8ca5b8d`) | `3b355c5` |

## Moving to a newer upstream version

1. Create a new orphan branch `hyggio/vX.Y.Z` with the unmodified upstream tree of `vX.Y.Z`.
2. Cherry-pick commits 2 and 3 from the previous branch. On a conflict in `user_pool.go`
   re-apply the current PR diff. If the PR head changed, record the new SHA here and in
   `.github/scripts/check-provenance.sh` together with the new upstream tag and commit.
3. Tag `vX.Y.Z`.

## End of life

When upstream releases `web_authn_configuration.factor_configuration`, switch back to
`hashicorp/aws` and this repository will be archived. Releases are kept (not deleted),
because the Terraform Registry downloads them from GitHub and existing lock files depend
on them.

## License

[Mozilla Public License 2.0](LICENSE), same as upstream. All source files keep their
upstream copyright and license headers. The complete corresponding source code of every
release is the tagged commit in this repository.
