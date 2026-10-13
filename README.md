# devsecops-pipeline-github-actions

Security built into the CI/CD pipeline (shift-left). Every push and pull request runs automated security stages that scan dependencies, source code, Docker images and Terraform files, and look for leaked secrets. The pipeline fails on critical or high findings, and every scan saves its report as a pipeline artifact.

**Author:** Bassem Jamal Hussein | DevSecOps & Cloud Engineer | [GitHub: jamalgoogle](https://github.com/jamalgoogle)

## Stack

GitHub Actions, Trivy, Gitleaks, SonarQube, OWASP Dependency-Check, Docker, Terraform, Node.js, SARIF, CycloneDX SBOM, Dependabot

## Pipeline

```
 push / pull request / weekly schedule
                 |
   +-------------+-----------------------------------------------+
   |             |              |             |                  |
   v             v              v             v                  v
 Unit tests   Gitleaks      Dependencies    SonarQube          Trivy
              (secrets)     npm audit       (SAST +            config
                            Trivy           quality gate)      (Terraform,
                            Dependency-                        Dockerfile)
                            Check
   |
   v
 Build image -> Trivy image scan (+ SBOM)
   |             |              |             |                  |
   +-------------+--------------+-------------+------------------+
                 |
                 v
        Security gate (all stages must pass)
                 |
                 v
   Reports saved as artifacts + findings in the GitHub Security tab
```

## Security stages

| Stage | Tool | What it checks | Fails the pipeline when | Report artifact |
| --- | --- | --- | --- | --- |
| Secrets | Gitleaks | Full git history for API keys, tokens, private keys, passwords | Any secret is found | `gitleaks-report` (SARIF) |
| Dependencies | npm audit | Production npm dependencies | High or critical advisory | console output |
| Dependencies | Trivy (`fs`) | Lockfile vulnerabilities, fixed ones only | HIGH or CRITICAL | `dependency-reports` (JSON, SARIF, HTML) |
| Dependencies | OWASP Dependency-Check | Known CVEs from the NVD | CVSS 7.0 or higher | `dependency-reports` (HTML, JSON) |
| Code (SAST) | SonarQube | Bugs, vulnerabilities and security hotspots in `app/src` | Quality gate fails | `sonarqube-report` (issues JSON) |
| Infrastructure as code | Trivy (`config`) | Terraform and Dockerfile misconfigurations | HIGH or CRITICAL | `iac-report` (JSON, SARIF, HTML) |
| Container image | Trivy (`image`) | OS packages, libraries and embedded secrets in the built image | HIGH or CRITICAL | `image-report` (JSON, SARIF, HTML, SBOM) |

All reports are kept for 30 days. SARIF reports are also published to the repository's **Security > Code scanning** tab (public repositories or GitHub Advanced Security). A weekly scheduled run catches vulnerabilities published after the last commit.

The final **Security gate** job summarizes every stage in the run summary and fails if any stage failed. Mark it as a required status check in the branch protection rules so a red security stage blocks the merge.

## Repository structure

```
app/                              Sample Node.js API (Express + Helmet), Dockerfile, tests
terraform/                        Secure AWS baseline: KMS, S3, ECR, security group (passes the gate)
examples/insecure-terraform/      Intentionally insecure Terraform used to show the gate failing
sonarqube/docker-compose.yml      Self-hosted SonarQube Community Build for the SAST stage
scripts/ci-trivy.sh               One Trivy runner used by both CI and local scans (report + gate)
scripts/run-local-scans.sh        Run the scanners on your machine
scripts/demo-leak.sh              Shows Gitleaks catching a committed secret
.gitleaks.toml                    Gitleaks config (default rules + allowlist)
.trivyignore                      Accepted Trivy findings (with expiry dates)
dependency-check-suppression.xml  Accepted Dependency-Check findings (with expiry dates)
sonar-project.properties          SonarQube project config (quality gate must pass)
.github/workflows/devsecops.yaml  The pipeline
.github/dependabot.yml            Weekly dependency updates (npm, Docker, Terraform, Actions)
```

## Setup

1. **Repository secrets** (Settings > Secrets and variables > Actions):

   | Secret | Purpose |
   | --- | --- |
   | `SONAR_TOKEN` | SonarQube user token |
   | `SONAR_HOST_URL` | URL of your SonarQube server |
   | `NVD_API_KEY` | Free NVD API key. Without it, Dependency-Check downloads the vulnerability data very slowly |

   If the two SonarQube secrets are missing, the SAST stage logs a warning and is skipped. Set them to enforce it.

2. **SonarQube server.** Run the included Compose file on a host that GitHub Actions can reach over HTTPS (or use a self-hosted runner):

   ```bash
   export SONAR_DB_PASSWORD='choose-a-strong-password'
   docker compose -f sonarqube/docker-compose.yml up -d
   ```

   Then open port 9000, create a project with the key `jamalgoogle_devsecops-pipeline-github-actions`, and generate a token. The host needs `vm.max_map_count=262144`.

3. **Branch protection.** Require the **Security gate** check on `main`.

## Run the scans locally

Requires Docker and uses the same pinned scanner images as the pipeline.

```bash
./scripts/run-local-scans.sh            # secrets, dependencies, IaC
./scripts/run-local-scans.sh image      # build the image and scan it
```

Reports are written to `reports/`.

## Demo: watch the gate fail

**Leaked secret.** Creates a throwaway repository with fake credentials and runs Gitleaks on it (this repository is not touched):

```bash
./scripts/demo-leak.sh
```

**Insecure infrastructure.** Scans the intentionally insecure Terraform. Trivy reports 10 findings at HIGH or CRITICAL (public S3 ACL, SSH open to `0.0.0.0/0`, unrestricted egress, unencrypted and public RDS) and exits with an error:

```bash
./scripts/run-local-scans.sh examples
```

The files in `terraform/` pass the same scan: KMS key with rotation, S3 bucket with public access blocked, versioning and KMS encryption, ECR with immutable tags and scan on push, and a security group limited to HTTPS from a private range.

**Vulnerable dependency.** Pin an old vulnerable version in `app/package.json` on a test branch (for example an outdated `express`) and open a pull request. The dependency stage fails and the Trivy, npm audit and Dependency-Check output show the CVE and the fixed version.

## Handling false positives

Findings are never silenced without a reason and an expiry date, so they come back for review:

- Trivy: add the ID to `.trivyignore` with an `exp:` date.
- Dependency-Check: add a `<suppress until="...">` entry with notes to `dependency-check-suppression.xml`.
- Gitleaks: add the path or a rule allowlist to `.gitleaks.toml`.
- SonarQube: mark the issue as accepted or false positive in the SonarQube UI, with a comment.

## Pinned versions

Scanner images are pinned at the top of the workflow (`TRIVY_IMAGE`, `GITLEAKS_IMAGE`, `DEPCHECK_IMAGE`) so a new release never changes results unexpectedly. They were current when this was written. Update them on a schedule, and pin by image digest if you need a stronger supply chain guarantee.

## Notes

- Trivy downloads its vulnerability database from a public registry that can rate limit shared CI runners. The workflow caches the database between runs to reduce this.
- `--ignore-unfixed` is used for dependency and image scans, so the gate only fails on vulnerabilities that have a fix available. Remove it for a stricter policy.
- The Terraform in `terraform/` is scanned only. It is never applied by the pipeline.

## License

MIT, see [LICENSE](LICENSE).
