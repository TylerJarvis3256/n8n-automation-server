# 1. Initialize git in your current directory
git init

# 2. Create README with setup instructions
cat > README.md << 'EOF'
# n8n Automation Server Setup

Personal n8n instance for job search automation and workflow management.

## Quick Setup

1. Clone this repository
2. Copy `.env.example` to `.env` and fill in your values
3. Create required Docker volumes:
```bash
   docker volume create caddy_data
   docker volume create n8n_data
   docker volume create postgres_data
