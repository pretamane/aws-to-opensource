# File Organization Summary

## Directory Structure

```
aws-to-opensource/
├── docs/                           # All documentation
│   ├── status-reports/            # Status and reports
│   │   ├── ALL_SERVICES_WORKING.txt
│   │   ├── DEPLOYMENT_READY_REPORT.txt
│   │   ├── FINAL_SUMMARY.txt
│   │   ├── GRAFANA_FIXED.txt
│   │   ├── LIVE_DEPLOYMENT_INFO.txt
│   │   ├── MIGRATION_COMPLETE_SUMMARY.txt
│   │   └── TEST_DEPLOYMENT_SUCCESS.md
│   ├── guides/                    # How-to guides
│   │   ├── INTEGRATION_GUIDE.md
│   │   ├── PGADMIN_GUIDE.txt
│   │   ├── QUICK_ACCESS.md
│   │   └── QUICK_START.md
│   ├── IMPLEMENTATION_COMPLETE.md
│   ├── INDEX.md
│   ├── MIGRATION_PLAN.md
│   └── MIGRATION_SUMMARY.md
├── scripts/                       # All scripts
│   ├── deployment/               # Deployment scripts
│   │   ├── deploy-website-to-ec2.sh
│   │   ├── push-website-via-git.sh
│   │   └── upload-website-files.sh
│   ├── testing/                  # Testing scripts
│   │   ├── test-document-upload.sh
│   │   ├── test-opensearch-document.txt
│   │   └── test-s3-document.txt
│   └── maintenance/              # Maintenance scripts (from scripts/)
├── archives/                     # Historical files
│   ├── deployment-history/       # Deployment archives
│   │   ├── app-update*.tar.gz (7 files)
│   │   ├── caddy-fixed.tar.gz
│   │   └── pgadmin-*.tar.gz (2 files)
│   └── backups/                  # Backup files
├── docker-compose/               # Docker configuration
├── docker/                       # Application code
├── terraform/                    # Infrastructure code
├── terraform-ec2/               # EC2 infrastructure
├── pretamane-website/           # Portfolio website
└── README.md                    # Main project README
```

## What the tar.gz Files Are

The `.tar.gz` files in `archives/deployment-history/` are temporary deployment packages created during development:

### Application Updates (app-update*.tar.gz)
- **Purpose**: Contain application code updates
- **Created**: During development iterations
- **Sent to**: EC2 instance via AWS SSM
- **Status**: ✅ Already deployed, can be deleted

### Configuration Fixes (caddy-fixed.tar.gz)
- **Purpose**: Contains Caddy reverse proxy configuration fixes
- **Created**: When fixing subpath routing issues
- **Sent to**: EC2 instance to update Caddyfile
- **Status**: ✅ Already applied, can be deleted

### Database Admin Setup (pgadmin-*.tar.gz)
- **Purpose**: Contains pgAdmin configuration updates
- **Created**: When setting up PostgreSQL admin interface
- **Sent to**: EC2 instance to configure pgAdmin
- **Status**: ✅ Already configured, can be deleted

## Cleanup Recommendation

All tar.gz files in `archives/deployment-history/` can be safely deleted as they are:
- Already deployed to EC2
- Temporary development artifacts
- Taking up unnecessary space

```bash
# To clean up (optional):
rm -rf archives/deployment-history/*.tar.gz
```

## Quick Access

### Key Documentation
- **Quick Start**: `docs/guides/QUICK_START.md`
- **Integration Guide**: `docs/guides/INTEGRATION_GUIDE.md`
- **Status Reports**: `docs/status-reports/`

### Key Scripts
- **Deploy Website**: `scripts/deployment/push-website-via-git.sh`
- **Test APIs**: `scripts/testing/test-document-upload.sh`

### Live System
- **Homepage**: http://54.179.230.219/
- **API Docs**: http://54.179.230.219/docs
- **Grafana**: http://54.179.230.219/grafana/
- **pgAdmin**: http://54.179.230.219/pgadmin
