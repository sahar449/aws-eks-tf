# 🚀 Full AWS EKS Infrastructure with Terraform and GitHub Actions

This project demonstrates how to provision and manage a complete AWS infrastructure using Terraform, deploy a Flask app to Amazon EKS, and automate CI/CD workflows with GitHub Actions. It includes comprehensive security scanning with Trivy and container signing with Cosign.

## 📐 Architecture

![AWS EKS Infrastructure](picture.png)

```
Developer --> GitHub --> GitHub Actions --> Terraform --> AWS (EKS, ECR, IAM, VPC)
                            |
                            --> Trivy Security Scan
                            |
                            --> Docker Build --> ECR
                            |
                            --> Cosign Container Signing
                            |
                            --> Helm Deploy --> EKS
```

## 🧾 Project Structure

```
.
├── .github/
│   └── workflows/
│       └── ci-cd.yml           # GitHub Actions CI/CD pipeline
├── terraform/                  # Terraform configurations for AWS resources
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── terraform.tfvars
├── flask-app/                  # Flask application with Helm chart
│   ├── templates/
│   ├── values.yaml
│   └── Chart.yaml
├── app.py                      # Flask application code
├── Dockerfile                  # Flask app container
├── requirements.txt            # Python dependencies
└── README.md
```

## 🛠 Prerequisites

Make sure you have the following configured:

- **AWS Account** with sufficient IAM permissions
- **GitHub Repository** with the following secrets configured:
  - `AWS_ACCOUNT_ID` - Your AWS Account ID
  - `AWS_ACCESS_KEY_ID` - AWS Access Key (for OIDC alternative)
  - `AWS_SECRET_ACCESS_KEY` - AWS Secret Key (for OIDC alternative)
  - `COSIGN_PRIVATE` - Base64 encoded Cosign private key (optional)
  - `COSIGN_PUBLIC` - Base64 encoded Cosign public key (optional)
  - `COSIGN_PASSWORD` - Cosign key password (optional)

## 🔐 Security Features

### 1. **Trivy Security Scanning**
- **Filesystem scanning** for vulnerabilities
- **Configuration scanning** for misconfigurations
- **Secret detection** in code
- **OS and library vulnerability** scanning

### 2. **Cosign Container Signing**
- **Keyless signing** using GitHub OIDC (recommended)
- **Key-based signing** for custom keys
- **Signature verification** before deployment
- **Supply chain security** compliance

### 3. **AWS OIDC Integration**
- **Secure authentication** without long-term credentials
- **Least privilege** access
- **Audit trail** for all actions

## ⚙️ Setup Instructions

### 1. Clone the Repository

```bash
git clone https://github.com/sahar449/Full-AWS-EKS-Infrastructure-with-Terraform-and-GitHub-Actions.git
cd Full-AWS-EKS-Infrastructure-with-Terraform-and-GitHub-Actions
```

### 2. Configure AWS OIDC (Recommended)

Create an OIDC provider and IAM role in AWS:

```bash
# Create OIDC provider (one-time setup)
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1

# Create IAM role with trust policy for your GitHub repo
# Replace YOUR_GITHUB_USERNAME and YOUR_REPO_NAME
```

### 3. Configure GitHub Secrets

#### Required Secrets:
```bash
AWS_ACCOUNT_ID=123456789012
```

#### For OIDC (Recommended):
```bash
# Add your OIDC role ARN to the workflow
OIDC_ROLE_ARN=arn:aws:iam::123456789012:role/github-actions-role
```

#### For Access Keys (Alternative):
```bash
AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
```

### 4. Configure Terraform Variables

Edit `terraform/terraform.tfvars`:

```hcl
region       = "us-west-2"
cluster_name = "eksdemo-cluster"
```

### 5. Set Up Cosign (Optional)

#### Option A: Keyless Signing (Recommended)
No setup required! The workflow uses GitHub OIDC automatically.

#### Option B: Custom Keys
```bash
# Generate keys
cosign generate-key-pair

# Encode for GitHub Secrets
base64 -w 0 cosign.key > cosign_private.txt
base64 -w 0 cosign.pub > cosign_public.txt

# Add to GitHub Secrets:
# COSIGN_PRIVATE: content of cosign_private.txt
# COSIGN_PUBLIC: content of cosign_public.txt
# COSIGN_PASSWORD: your key password
```

## 🔄 CI/CD Pipeline

The GitHub Actions workflow (`.github/workflows/ci-cd.yml`) performs:

### 1. **Security Scanning**
```yaml
- name: Run Trivy Full Scan
  uses: aquasecurity/trivy-action@master
  with:
    scan-type: 'fs'
    vuln-type: 'os,library'
    scanners: 'vuln,config,secret'
```

### 2. **Infrastructure Provisioning**
```yaml
- name: Terraform Apply
  run: |
    terraform init
    terraform apply -auto-approve
```

### 3. **Container Build & Push**
```yaml
- name: Build and Push to ECR
  run: |
    docker build -t $ECR_URI:$IMAGE_TAG .
    docker push $ECR_URI:$IMAGE_TAG
```

### 4. **Container Signing**
```yaml
# Keyless signing
- name: Sign Container Image
  run: cosign sign --yes $ECR_URI:$IMAGE_TAG

# Or with keys
- name: Sign with Custom Key
  run: cosign sign --key cosign.key $ECR_URI:$IMAGE_TAG
```

### 5. **Deployment to EKS**
```yaml
- name: Deploy with Helm
  run: |
    helm upgrade --install flask ./flask-app \
      --set image.repository=$ECR_URI \
      --set image.tag=$IMAGE_TAG
```

## 🚀 Deployment Options

### Manual Trigger
```bash
# Go to GitHub Actions tab
# Click "Run workflow"
# Choose "apply" or "destroy"
```

### Automatic Triggers
- **Push to main branch** - triggers apply
- **Pull request** - triggers plan only
- **Manual dispatch** - choose apply/destroy

## 🧪 Testing the Application

### 1. **Port Forward (Development)**
```bash
kubectl port-forward service/flask-service 8080:5000
curl http://localhost:8080
```

### 2. **Load Balancer (Production)**
```bash
# Get LoadBalancer URL
kubectl get service flask-service
# Expected output: EXTERNAL-IP with AWS ELB
```

### 3. **Verify Container Signature**
```bash
# For keyless signing
cosign verify \
  --certificate-identity-regexp=".*" \
  --certificate-oidc-issuer-regexp=".*" \
  $ECR_URI:$IMAGE_TAG

# For key-based signing
cosign verify --key cosign.pub $ECR_URI:$IMAGE_TAG
```

## 📊 Monitoring and Troubleshooting

### Check Pod Status
```bash
kubectl get pods
kubectl describe pod <pod-name>
kubectl logs <pod-name>
```

### Check Security Scan Results
```bash
# View Trivy scan in GitHub Actions logs
# Check for HIGH/CRITICAL vulnerabilities
```

### Verify Cosign Signatures
```bash
# List all signatures
cosign tree $ECR_URI:$IMAGE_TAG
```

## 🔧 Configuration Options

### Environment Variables
```yaml
env:
  image_tag: latest
  aws_region: us-west-2
  cluster_name: eksdemo-cluster
  ecr_name: my-app
```

### Workflow Inputs
```yaml
workflow_dispatch:
  inputs:
    apply_or_destroy:
      description: 'Apply or destroy infrastructure'
      required: true
      default: 'apply'
      type: choice
      options:
        - apply
        - destroy
```

## 🧹 Cleanup

### Destroy Infrastructure
```bash
# Via GitHub Actions
# Go to Actions → Run workflow → Choose "destroy"

# Or manually
cd terraform
terraform destroy -auto-approve
```

### Remove Container Images
```bash
# Delete ECR repository
aws ecr delete-repository --repository-name my-app --force
```

## 🔒 Security Best Practices

### ✅ Implemented
- **Container image scanning** with Trivy
- **Infrastructure as Code scanning**
- **Container signing** with Cosign
- **OIDC authentication** (no long-term keys)
- **Least privilege IAM** roles
- **Non-root container** execution
- **Secret detection** in code

### 🔄 Recommended Additions
- **Network policies** for pod-to-pod communication
- **Pod security standards** enforcement
- **Resource limits** and quotas
- **Admission controllers** (OPA Gatekeeper)
- **Runtime security** monitoring

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **Trivy** by Aqua Security for vulnerability scanning
- **Cosign** by Sigstore for container signing
- **GitHub Actions** for CI/CD automation
- **Terraform** by HashiCorp for infrastructure provisioning
- **Helm** for Kubernetes application management

---

**⭐ Star this repository if it helped you!**