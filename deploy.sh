#!/bin/bash

# Step 1: Set variables
KEY_NAME="focalboard-key"  # Replace with your EC2 key pair name
SECURITY_GROUP="focalboard-sg"
INSTANCE_TYPE="t2.micro"
AMI_ID="ami-084568db4383264d4"  # Amazon Linux 2 AMI (region-specific)
REPO_URL="https://github.com/lizarizvi/focalboard.git"
REGION="us-east-1"

echo "🚀 Starting Focalboard deployment..."

# Step 2: Create a security group if it doesn't exist
aws ec2 describe-security-groups --group-names "$SECURITY_GROUP" > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "🔐 Creating security group..."
  aws ec2 create-security-group --group-name "$SECURITY_GROUP" --description "Focalboard SG"
  aws ec2 authorize-security-group-ingress --group-name "$SECURITY_GROUP" --protocol tcp --port 22 --cidr 0.0.0.0/0
  aws ec2 authorize-security-group-ingress --group-name "$SECURITY_GROUP" --protocol tcp --port 80 --cidr 0.0.0.0/0
fi

# Step 3: Launch EC2 instance
echo "💻 Launching EC2 instance..."
INSTANCE_ID=$(aws ec2 run-instances \
  --image-id $AMI_ID \
  --count 1 \
  --instance-type $INSTANCE_TYPE \
  --key-name $KEY_NAME \
  --security-groups $SECURITY_GROUP \
  --query 'Instances[0].InstanceId' \
  --output text)

# Step 4: Wait until EC2 instance is running
echo "⏳ Waiting for EC2 to be in 'running' state..."
aws ec2 wait instance-running --instance-ids $INSTANCE_ID

# Step 5: Get the public IP
PUBLIC_IP=$(aws ec2 describe-instances \
  --instance-ids $INSTANCE_ID \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text)

echo "✅ EC2 is running at $PUBLIC_IP"

# Step 6: SSH into instance and set up environment
echo "🔧 Configuring instance..."

ssh -o StrictHostKeyChecking=no -i "$KEY_NAME.pem" ec2-user@$PUBLIC_IP <<EOF
  sudo yum update -y
  sudo yum install -y docker git
  sudo service docker start
  sudo usermod -a -G docker ec2-user

  git clone $REPO_URL
  cd focalboard
  docker build -t focalboard .
  docker run -d -p 80:8000 focalboard
EOF

echo "🌐 Deployment complete. Visit: http://$PUBLIC_IP"
