//Authentication
variable "access_key"{
}

variable "secret_key"{
}

provider "aws"{
    region = "us-east-1"
    access_key = var.access_key
    secret_key = var.secret_key
}

//Authentication



//VPC & Subnets
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "subnet1" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"
}

resource "aws_subnet" "subnet2" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-east-1b"
}
//VPC & Subnets

//IAM Role//
resource "aws_iam_role" "ec2_ssm_role" {
  name = "EC2SSMRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action    = "sts:AssumeRole",
        Effect    = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      } 
    ]
  })
}

resource "aws_iam_policy_attachment" "ec2_ssm_policy" {
  name       = "attach-ssm-policy"
  roles      = [aws_iam_role.ec2_ssm_role.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_policy" "ec2_s3_policy" {
  name        = "EC2S3AccessPolicy"
  description = "Allows EC2 instance to list S3 buckets"
  policy      = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Action    = "s3:*",
        Resource  = "*"
      }
    ]
  })
}

# Attach the S3 policy to the role
resource "aws_iam_policy_attachment" "ec2_s3_policy_attachment" {
  name       = "attach-ec2-s3-policy"
  roles      = [aws_iam_role.ec2_ssm_role.name]
  policy_arn = aws_iam_policy.ec2_s3_policy.arn
}

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "NewEC2InstanceProfile"
  role = aws_iam_role.ec2_ssm_role.name
}

//IAM Role//

//EC2 & Security Group
resource "aws_instance" "EC2-Subnet1" {
  ami           = "ami-0c02fb55956c7d316"  # Replace with your desired AMI
  instance_type = "t2.micro"
  iam_instance_profile = aws_iam_instance_profile.ec2_instance_profile.name
  subnet_id              = aws_subnet.subnet1.id  # Associate with the specific subnet
  vpc_security_group_ids = [aws_security_group.allow_web.id]  # Attach the security group
}

resource "aws_security_group" "allow_web" {
  name        = "allow_web"
  description = "Allow web inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.main.id
}

resource "aws_vpc_security_group_egress_rule" "allow_tls_SSH" {
  security_group_id = aws_security_group.allow_web.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 0
  ip_protocol       = "-1"
  to_port           = 65535
}

resource "aws_vpc_security_group_ingress_rule" "allow_tls_SSH" {
  security_group_id = aws_security_group.allow_web.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}
//EC2 & Security Group

//EC2 Instance Connect Endpoint//
resource "aws_ec2_instance_connect_endpoint" "EC2InstanceConnectEndpoint" {
  subnet_id      = aws_subnet.subnet1.id
  security_group_ids = [aws_security_group.allow_web.id]

}
//EC2 Instance Connect Endpoint//

//VPC Router/Route Table & Associations//
resource "aws_route_table" "vpcrouter" {
  vpc_id = aws_vpc.main.id

}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet1.id
  route_table_id = aws_route_table.vpcrouter.id
}

resource "aws_route_table_association" "b" { //This is a separate function due to the fact that subnets in aws are defaulted to the default route table.
  subnet_id      = aws_subnet.subnet2.id
  route_table_id = aws_route_table.vpcrouter.id
}


//VPC Router/Route Table & Associations//


//Gateway Endpoint & Endpoint Policies//
resource "aws_vpc_endpoint" "gatewayendpoint" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.us-east-1.s3"
  depends_on = [aws_route_table.vpcrouter]
  route_table_ids = [aws_route_table.vpcrouter.id] //You need to associate this with the route table

  policy = jsonencode({
    Version:"2012-10-17",
    Statement:[
    {
        Effect:"Allow",
        Principal: "*",
        Action: "s3:*",
        Resource:[ 
        "arn:aws:s3:::private4cats/*",
        "arn:aws:s3:::publiccats/*"
        ]
    },
    {
        Effect : "Allow",
        Principal : "*",
        Action : "s3:ListBucket",
        Resource : [
        "arn:aws:s3:::private4cats",
        "arn:aws:s3:::publiccats"
        ]
    },
    {
        Effect : "Allow",
        Principal: "*",
        Action:[
        "s3:ListAllMyBuckets",
        "s3:GetBucketLocation"
        ],
        Resource : "*"
    }
    ]
})
}
//Gateway Endpoint//

//S3 Buckets & Content Uploaded into bucket
resource "aws_s3_bucket" "private4cats" {
    bucket = "private4cats"
}

resource "aws_s3_bucket" "publiccats" {
    bucket = "publiccats"
}

resource "aws_s3_bucket" "dogpics2" {
    bucket = "dogpics2realcopy"
}

resource "aws_s3_object" "private4catsobject" {
  bucket = "private4cats"
  key    = "new_object_key"
  source = "D:/TerraformProjects/RAM.TF/privatecats.webp"
  depends_on = [aws_s3_bucket.private4cats]

  etag = filemd5("D:/TerraformProjects/RAM.TF/privatecats.webp")
}

resource "aws_s3_bucket_policy" "private4catsbucketpolicy" {
  bucket = aws_s3_bucket.private4cats.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:*"
        Resource  = ["arn:aws:s3:::private4cats", "arn:aws:s3:::private4cats/*"]
        Condition = {
          StringEquals = {
            "aws:SourceVpce" = "${aws_vpc_endpoint.gatewayendpoint.id}"
          }
        }
      },{
        Effect    = "Deny"
        Principal = "*"
        Action    = ["s3:ListBucket","s3:GetObject"]
        Resource  = ["arn:aws:s3:::private4cats", "arn:aws:s3:::private4cats/*"]
        Condition = {
          StringNotEquals = {
            "aws:SourceVpce" = "${aws_vpc_endpoint.gatewayendpoint.id}"
          }
        }
      }
    ]
  })
}

resource "aws_s3_object" "publiccatsobject" {
  bucket = "publiccats"
  key    = "new_object_key"
  source = "D:/TerraformProjects/RAM.TF/publiccats.webp"
  depends_on = [aws_s3_bucket.publiccats]

  # The filemd5() function is available in Terraform 0.11.12 and later
  # For Terraform 0.11.11 and earlier, use the md5() function and the file() function:
  # etag = "${md5(file("path/to/file"))}"
  etag = filemd5("D:/TerraformProjects/RAM.TF/publiccats.webp")
}

resource "aws_s3_object" "dogpics2object" {
  bucket = "dogpics2realcopy"
  key    = "new_object_key"
  source = "D:/TerraformProjects/RAM.TF/dogpics.webp"
  depends_on = [aws_s3_bucket.dogpics2]

  # The filemd5() function is available in Terraform 0.11.12 and later
  # For Terraform 0.11.11 and earlier, use the md5() function and the file() function:
  # etag = "${md5(file("path/to/file"))}"
  etag = filemd5("D:/TerraformProjects/RAM.TF/dogpics.webp")
}

//S3 Buckets
