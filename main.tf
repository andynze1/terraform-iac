provider "aws" {
  region = "us-east-1"
}

// CREATE VPC
resource "aws_vpc" "dml-vpc" {
  cidr_block = "10.1.0.0/16"
  tags = {
    Name = "dml-vpc"
  }
}

// CREATE PUBLIC AND PRIVATE SUBNETS
resource "aws_subnet" "dml-public-subnet-01" {
  vpc_id            = aws_vpc.dml-vpc.id
  cidr_block        = "10.1.1.0/24"
  map_public_ip_on_launch = true
  availability_zone = "us-east-1a"
  tags = {
    Name = "dml-public-subnet-01"
  }
}
resource "aws_subnet" "dml-private-subnet-02" {
  vpc_id            = aws_vpc.dml-vpc.id
  cidr_block        = "10.1.2.0/24"
  map_public_ip_on_launch = true
  availability_zone = "us-east-1b"
  tags = {
    Name = "dml-public-subnet-02"
  }
}

// Create Internet Gateway for VPC
resource "aws_internet_gateway" "dml-igw" {
  vpc_id = aws_vpc.dml-vpc.id
  tags = {
    Name = "dml-igw"
  }
}

// Create Route Table
resource "aws_route_table" "dml-public-rt" {
  vpc_id = aws_vpc.dml-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.dml-igw.id
  }
  tags = {
    Name = "dml-public-rt"
  }
}

// Associate subnets with route table
resource "aws_route_table_association" "dml-rta-public-subnet-01" {
  subnet_id      = aws_subnet.dml-public-subnet-01.id
  route_table_id = aws_route_table.dml-public-rt.id
}

resource "aws_route_table_association" "dml-rta-private-subnet-02" {
  subnet_id      = aws_subnet.dml-private-subnet-02.id
  route_table_id = aws_route_table.dml-public-rt.id
}

// CREATE ALL SECURITY GROUPS//

// Create Jenkins Security Group
resource "aws_security_group" "Jenkins-SG" {
  name        = "Jenkins-SG"
  description = "Jenkins Security Group"
  vpc_id      = aws_vpc.dml-vpc.id

  ingress {
    description = "Allow SSH Traffic"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Allow Jenkins Traffic"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  ingress {
    description        = "Allow 8080 Traffic"
    from_port          = 8080
    to_port            = 8080
    protocol           = "tcp"
    cidr_blocks        = ["0.0.0.0/0"]
    ipv6_cidr_blocks   = ["::/0"]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  tags = {
    Name = "Jenkins-SG"
  }
}
// Create Security Group Rule allowing all traffic from Sonar-SG to Jenkins-SG
resource "aws_security_group_rule" "allow_from_sonarqube_to_jenkins" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1" # All protocols
  security_group_id        = aws_security_group.Jenkins-SG.id
  source_security_group_id = aws_security_group.Sonar-SG.id
}

// Create Sonar Security Group
resource "aws_security_group" "Sonar-SG" {
  name        = "Sonar-SG"
  description = "Sonar Security Group"
  vpc_id      = aws_vpc.dml-vpc.id

  ingress {
    description = "Allow SSH Traffic"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Allow SSH Traffic"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  tags = {
    Name = "Sonar-SG"
  }
}
// Create Security Group Rule allowing all traffic from Jenkins-SG to Sonar-SG
resource "aws_security_group_rule" "allow_from_jenkins_to_sonarqube" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1" # All protocols
  security_group_id        = aws_security_group.Sonar-SG.id
  source_security_group_id = aws_security_group.Jenkins-SG.id
}

# Create Nexus Security Group
resource "aws_security_group" "Nexus-SG" {
  name        = "Nexus-SG"
  description = "Nexus Security Group"
  vpc_id      = aws_vpc.dml-vpc.id

  ingress {
    description = "Allow SSH Traffic"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Allow 8081 Traffic"
    from_port   = 8081
    to_port     = 8081
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks   = ["::/0"]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  tags = {
    Name = "Nexus-SG"
  }
}
// Create Security Group Rule allowing all traffic from Jenkins-SG to Nexus-SG
resource "aws_security_group_rule" "allow_all_Nexus-SG" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1" # All protocols
  security_group_id        = aws_security_group.Nexus-SG.id
  source_security_group_id = aws_security_group.Jenkins-SG.id
  }

# SERVERS TO PROVISION
# Jenkns Ubuntu
  resource "aws_instance" "jenkins-master" {
  ami                    = "ami-0e001c9271cf7f3b9"
  instance_type          = "t2.medium"
  key_name               = "aws-key1"
  vpc_security_group_ids = [aws_security_group.Jenkins-SG.id]
  subnet_id              = aws_subnet.dml-public-subnet-01.id
  for_each               = tomap({
    "jenkins-master" = <<-EOF
            #!/bin/bash
            sudo hostnamectl set-hostname jenkins-master
            sudo yum update -y
            sudo apt update
            sudo apt install fontconfig openjdk-11-jdk openjdk-8-jdk -y
            sudo apt install maven wget unzip -y
            curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo tee  /usr/share/keyrings/jenkins-keyring.asc > /dev/null
            echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/ | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null
            sudo apt-get update
            sudo apt-get install jenkins -y
            sudo systemctl enable jenkins
            sudo systemctl start jenkins
            EOF
  })
    user_data = each.value

    tags = {
      Name = "${each.key}"
    }
}

# Nexus Amazon Linux Server
resource "aws_instance" "nexus-server" {
  ami                    = "ami-0bb84b8ffd87024d8"
  instance_type          = "t2.medium"
  key_name               = "aws-key1"
  vpc_security_group_ids = [aws_security_group.Nexus-SG.id]
  subnet_id              = aws_subnet.dml-public-subnet-01.id
  for_each               = tomap({
    "nexus-server" = <<-EOF
        #!/bin/bash
        sudo hostnamectl set-hostname nexus-server
        sudo yum update -y
        sudo yum install -y wget java-1.8.0-amazon-corretto.x86_64
        sudo useradd nexus && echo 'nexus' | passwd --stdin nexus
        cd /opt && sudo wget https://download.sonatype.com/nexus/3/latest-unix.tar.gz
        sudo tar -zxvf latest-unix.tar.gz
        sudo mv nexus-3* nexus3
        sudo chown -R nexus:nexus /opt/nexus3
        sudo chown -R nexus:nexus /opt/sonatype-work
        cat <<EOT>> /etc/systemd/system/nexus.service
        [Unit]
        Description=nexus service
        After=network.target
        [Service]
        Type=forking
        LimitNOFILE=65536
        User=nexus
        Group=nexus
        ExecStart=/opt/nexus3/bin/nexus start
        ExecStop=/opt/nexus3/bin/nexus stop
        Restart=on-abort
        [Install]
        WantedBy=multi-user.target
        EOT
        sudo systemctl enable nexus
        sudo systemctl start nexus
        sudo sed -i 's/#run_as_user=""/run_as_user="nexus"/g' /opt/nexus3/bin/nexus.rc
        sudo firewall-cmd --permanent --add-port=8081/tcp
        sudo firewall-cmd --reload
        sudo systemctl status nexus
        EOF
  })
    user_data = each.value

    tags = {
      Name = "${each.key}"
    }
}
# Sonar Ubuntu Server
resource "aws_instance" "sonar-server" {
  ami                    = "ami-0e001c9271cf7f3b9"
  instance_type          = "t2.medium"
  key_name               = "aws-key1"
  vpc_security_group_ids = [aws_security_group.Sonar-SG.id]
  subnet_id              = aws_subnet.dml-public-subnet-01.id
  for_each               = tomap({
  "sonar-server" = <<-EOF
    #!/bin/bash
    sudo hostnamectl set-hostname sonar-server
    cp /etc/sysctl.conf /root/sysctl.conf_backup
    cat <<EOT > /etc/sysctl.conf
    vm.max_map_count=262144
    fs.file-max=65536
    ulimit -n 65536
    ulimit -u 4096
    EOT
    cp /etc/security/limits.conf /root/sec_limit.conf_backup
    cat <<EOT > /etc/security/limits.conf
    sonarqube   -   nofile   65536
    sonarqube   -   nproc    4096
    EOT
    sudo apt-get update -y
    sudo apt-get install openjdk-11-jdk -y
    sudo update-alternatives --config java
    java -version
    sudo apt update
    sh ./postgress.sh
    sudo mkdir -p /sonarqube/
    cd /sonarqube/
    sudo curl -O https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-8.3.0.34182.zip
    sudo apt-get install zip -y
    sudo unzip -o sonarqube-8.3.0.34182.zip -d /opt/
    sudo mv /opt/sonarqube-8.3.0.34182/ /opt/sonarqube
    sudo groupadd sonar
    sudo useradd -c "SonarQube - User" -d /opt/sonarqube/ -g sonar sonar
    sudo chown sonar:sonar /opt/sonarqube/ -R
    cp /opt/sonarqube/conf/sonar.properties /root/sonar.properties_backup
    cat <<EOT > /opt/sonarqube/conf/sonar.properties
    sonar.jdbc.username=sonar
    sonar.jdbc.password=admin123
    sonar.jdbc.url=jdbc:postgresql://localhost/sonarqube
    sonar.web.host=0.0.0.0
    sonar.web.port=9000
    sonar.web.javaAdditionalOpts=-server
    sonar.search.javaOpts=-Xmx512m -Xms512m -XX:+HeapDumpOnOutOfMemoryError
    sonar.log.level=INFO
    sonar.path.logs=logs
    EOT
    cat <<EOT > /etc/systemd/system/sonarqube.service
    [Unit]
    Description=SonarQube service
    After=syslog.target network.target
    [Service]
    Type=forking
    ExecStart=/opt/sonarqube/bin/linux-x86-64/sonar.sh start
    ExecStop=/opt/sonarqube/bin/linux-x86-64/sonar.sh stop
    User=sonar
    Group=sonar
    Restart=always
    LimitNOFILE=65536
    LimitNPROC=4096
    [Install]
    WantedBy=multi-user.target
    EOT
    sudo systemctl daemon-reload
    sudo systemctl enable sonarqube.service
    sudo apt-get install nginx -y
    sudo rm -rf /etc/nginx/sites-enabled/default
    sudo rm -rf /etc/nginx/sites-available/default
    cat <<EOT > /etc/nginx/sites-available/sonarqube
    server {
        listen      80;
        server_name sonarqube.groophy.in;
        access_log  /var/log/nginx/sonar.access.log;
        error_log   /var/log/nginx/sonar.error.log;
        proxy_buffers 16 64k;
        proxy_buffer_size 128k;
        location / {
            proxy_pass  http://127.0.0.1:9000;
            proxy_next_upstream error timeout invalid_header http_500 http_502 http_503 http_504;
            proxy_redirect off;
            proxy_set_header    Host            \$host;
            proxy_set_header    X-Real-IP       \$remote_addr;
            proxy_set_header    X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header    X-Forwarded-Proto http;
        }
    }
    EOT
    sudo ln -s /etc/nginx/sites-available/sonarqube /etc/nginx/sites-enabled/sonarqube
    sudo systemctl enable nginx.service
    sudo ufw allow 80,9000,9001/tcp
    echo "System reboot in 30 sec"
    sleep 30
    sudo reboot
  EOF
  })
    user_data = each.value

    tags = {
      Name = "${each.key}"
    }
}
