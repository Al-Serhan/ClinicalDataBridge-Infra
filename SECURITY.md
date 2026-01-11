# Security Policy

## Overview

ClinicalDataBridge infrastructure handles Protected Health Information (PHI) and must maintain HIPAA compliance. Security is our top priority.

## Reporting Security Issues

**CRITICAL: DO NOT open public GitHub issues for security vulnerabilities.**

### How to Report

For security vulnerabilities or concerns:

1. **Email**: Contact the repository owner directly
2. **Private Communication**: Use secure channels only
3. **Include**:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if available)

### Response Time

- **Critical vulnerabilities**: Response within 24 hours
- **High severity**: Response within 48 hours
- **Medium/Low severity**: Response within 1 week

## Security Requirements

### Code Changes

All code changes must:
- Pass pre-commit security checks (tfsec, checkov)
- Include security impact assessment for infrastructure changes
- Be reviewed for HIPAA compliance implications
- Pass all automated security scans

### Commit Requirements

- All commits should be GPG signed (recommended when team grows)
- Commit messages must be clear and descriptive
- No secrets, credentials, or sensitive data in commits
- Follow conventional commit format

### Infrastructure Security

**Required for all deployments:**
- Encryption at rest (EBS volumes with KMS)
- Encryption in transit (TLS/SSH)
- VPC Flow Logs enabled
- CloudWatch monitoring enabled
- Security groups with least privilege
- No public IPs on data processing VMs
- Bastion access restricted to known IPs

### Secrets Management

**Never commit:**
- AWS credentials or access keys
- SSH private keys (.pem files)
- API tokens or passwords
- terraform.tfvars with sensitive data
- Any file matching patterns in .gitignore

**Use instead:**
- AWS IAM roles and instance profiles
- AWS Secrets Manager or Parameter Store
- Environment variables (not committed)
- terraform.tfvars.example templates

## Security Checklist

Before deploying to production:

- [ ] All security scans pass (tfsec, checkov)
- [ ] VPC Flow Logs enabled
- [ ] CloudTrail logging enabled
- [ ] EBS encryption enabled with KMS
- [ ] Security groups reviewed (least privilege)
- [ ] Bastion admin_cidr set to specific IP (not 0.0.0.0/0)
- [ ] SSH keys rotated (90-day policy)
- [ ] CloudWatch alarms configured
- [ ] Remote state backend uses encryption
- [ ] MFA enabled on AWS accounts
- [ ] IAM policies follow least privilege
- [ ] No public IPs on private VMs
- [ ] AIDE file integrity monitoring enabled

## Compliance Requirements

### HIPAA Considerations

This infrastructure is designed with HIPAA compliance in mind:

- Data encrypted at rest and in transit
- Audit logging (VPC Flow Logs, CloudWatch, CloudTrail)
- Access controls (IAM, security groups)
- Integrity monitoring (AIDE)
- Data residency controls (US regions only)

**Note**: Full HIPAA compliance requires:
- Business Associate Agreement (BAA) with AWS
- Regular security assessments
- Documented policies and procedures
- Staff training
- Incident response plan

## Vulnerability Disclosure

We follow responsible disclosure practices:

1. Reporter notifies maintainer privately
2. Maintainer acknowledges within 48 hours
3. Maintainer investigates and develops fix
4. Fix is tested and deployed
5. Public disclosure after 90 days or when fix is deployed

## Security Updates

**Stay informed:**
- Monitor AWS security bulletins
- Watch OpenTofu/Terraform security advisories
- Keep dependencies updated (pre-commit autoupdate)
- Review security scan results regularly

## Current Security Posture

**Last Security Review**: January 2026
**Known Issues**: None
**Risk Level**: Low (development environment)

## Contact

**Repository Owner**: @Al-Serhan
**Security Contact**: (Add email when production-ready)

## Version History

- v1.0 (Jan 2026): Initial security policy
