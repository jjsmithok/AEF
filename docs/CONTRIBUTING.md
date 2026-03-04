# AWS Control Tower Documentation

This documentation is built with Mintlify and deployed to GitHub Pages.

## Quick Start

### Local Development
```bash
# Install Mintlify CLI
npm install -g mintlify

# Start local server
mintlify dev
```

### Building for Production
```bash
# Build static site
mintlify build

# Output is in ./mintlify/build
```

### Deploying to GitHub Pages
```bash
# Build the site
mintlify build

# Commit to gh-pages branch
cd mintlify/build
git init
git add .
git commit -m "Deploy documentation"
git push origin HEAD:gh-pages --force
```

## Editing Workflow

### Option 1: Edit Directly on GitHub
1. Navigate to the file in the repository
2. Click "Edit" (pencil icon)
3. Make changes in the Markdown editor
4. Commit changes with a message

### Option 2: Clone and Edit Locally
```bash
# Clone the repo
git clone https://github.com/openclaw/aws-control-tower-docs.git
cd aws-control-tower-docs

# Create a new branch
git checkout -b update-agents

# Edit files in your favorite editor
# Then commit and push
git add .
git commit -m "Update agent documentation"
git push origin update-update-agents

# Create a Pull Request
```

### Option 3: Submit Issues
If you spot errors or want to suggest changes:
1. Go to the GitHub repository
2. Click "Issues" → "New Issue"
3. Describe the change needed

## Mintlify Features

- **Live Preview** — Changes render in real-time during development
- **Search** — Built-in full-text search
- **Versioning** — Support for multiple versions
- **Customization** — Edit `docs.json` to change navigation, colors, etc.

## File Structure

```
/
├── README.md                 # Overview
├── docs.json                 # Mintlify configuration
├── 01-foundation/           # Week 1: IAM & Bootstrap
├── 02-control-tower/       # Weeks 2-3: Control Tower
├── 03-monitoring/          # Week 3: Observability
├── 04-security-agent/      # Week 4: Security
├── 05-network-agent/       # Week 4: Networking
├── 06-infrastructure-agent/# Week 5: Compute
├── 07-applications-agent/  # Week 6: Deployments
├── 08-member-agent/        # Week 6: Identity
├── 09-environments/        # Weeks 7-8: AWS Accounts
├── 10-governance/          # Week 9: HITL
├── 11-playbooks/           # Week 10: Resiliency
└── assets/                 # Images and static files
```

## Adding New Pages

1. Create a new `.md` file in the appropriate folder
2. Add to `docs.json` navigation section
3. Commit and deploy

## Support

- GitHub Issues: Report bugs or request features
- Documentation: https://mintlify.com/docs
