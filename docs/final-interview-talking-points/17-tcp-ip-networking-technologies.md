# TCP/IP Networking Technologies in This Repository

##  Overview

This document comprehensively covers **all TCP/IP networking technologies, protocols, and configurations** used in this repository. This stack demonstrates production-grade networking expertise across **all OSI model layers**:

- **Layer 2 (Data Link)**: Docker bridge networks, Ethernet bridging
- **Layer 3 (Network)**: VPC, subnets, routing tables, IP addressing, NAT
- **Layer 4 (Transport)**: TCP/UDP protocols, port management, connection tracking
- **Layer 5 (Session)**: TCP sessions, TLS sessions, session management
- **Layer 6 (Presentation)**: TLS/SSL encryption, certificates, cipher suites
- **Layer 7 (Application)**: HTTP, HTTPS, PostgreSQL, DNS, REST APIs

Each service and technology in this repository is tagged with its relevant OSI model layer(s) for comprehensive networking understanding.

---

##  OSI Model Reference

| Layer | Name | Technologies in This Stack | Examples |
|-------|------|---------------------------|----------|
| **L7** | Application | HTTP, HTTPS, PostgreSQL, DNS, REST APIs | FastAPI, Grafana, Prometheus |
| **L6** | Presentation | TLS/SSL, Encryption | TLS termination, SSL certificates |
| **L5** | Session | TCP sessions, TLS sessions | TCP handshake, session management |
| **L4** | Transport | TCP, UDP | Port management, connection tracking |
| **L3** | Network | IP, IPv4, routing, VPC, subnets | IP addressing, routing tables |
| **L2** | Data Link | Ethernet, bridges, MAC addresses | Docker bridge networks |
| **L1** | Physical | Network hardware | EC2 instance network interfaces |

---

##  Part 1: Network Protocols & Ports

### 1.1 Application Layer Protocols (Layer 7)

| Protocol | Port | Service | OSI Layer | Purpose | Configuration |
|----------|------|---------|-----------|---------|---------------|
| **HTTP** | 80 | Caddy | **L7** (over L4 TCP) | Reverse proxy, static site | `Caddyfile` |
| **HTTPS** | 443 | Cloudflare | **L7** (over L4 TCP, L6 TLS) | TLS termination | Cloudflare Tunnel |
| **HTTP** | 8000 | FastAPI | **L7** (over L4 TCP) | Application API | `app_opensource.py` |
| **HTTP** | 3000 | Grafana | **L7** (over L4 TCP) | Monitoring dashboards | `docker-compose.yml` |
| **HTTP** | 9090 | Prometheus | **L7** (over L4 TCP) | Metrics storage | `prometheus.yml` |
| **HTTP** | 3100 | Loki | **L7** (over L4 TCP) | Log aggregation | `loki-config.yml` |
| **HTTP** | 7700 | Meilisearch | **L7** (over L4 TCP) | Search API | `docker-compose.yml` |
| **HTTP** | 9000 | MinIO API | **L7** (over L4 TCP) | S3-compatible storage | `docker-compose.yml` |
| **HTTP** | 9001 | MinIO Console | **L7** (over L4 TCP) | Storage admin UI | `docker-compose.yml` |
| **HTTP** | 9080 | Promtail | **L7** (over L4 TCP) | Log shipper | `promtail-config.yml` |
| **HTTP** | 9115 | Blackbox | **L7** (over L4 TCP) | Synthetic monitoring | `blackbox.yml` |
| **HTTP** | 9093 | Alertmanager | **L7** (over L4 TCP) | Alert routing | `docker-compose.yml` |
| **HTTP** | 8080 | cAdvisor | **L7** (over L4 TCP) | Container metrics | `docker-compose.yml` |
| **HTTP** | 9100 | Node Exporter | **L7** (over L4 TCP) | Host metrics | `docker-compose.yml` |

### 1.2 Database Protocols (Layer 7)

| Protocol | Port | Service | OSI Layer | Purpose | Configuration |
|----------|------|---------|-----------|---------|---------------|
| **PostgreSQL** | 5432 | PostgreSQL | **L7** (over L4 TCP) | Database queries | `docker-compose.yml` |
| **PostgreSQL** | 5432 | pgAdmin | **L7** (over L4 TCP) | Database admin | `docker-compose.yml` |

### 1.3 Administrative Protocols (Layer 7)

| Protocol | Port | Service | OSI Layer | Purpose | Configuration |
|----------|------|---------|-----------|---------|---------------|
| **SSH** | 22 | SSH Server | **L7** (Application) over **L4** (TCP) | Secure shell access | Security groups, UFW |

### 1.4 Transport Layer Protocols (Layer 4)

| Protocol | Port Range | OSI Layer | Purpose | Configuration |
|----------|------------|-----------|---------|---------------|
| **TCP** | 22 | **L4** (Transport) | SSH access | Security groups |
| **TCP** | 80 | **L4** (Transport) | HTTP traffic | Security groups, Caddy |
| **TCP** | 443 | **L4** (Transport) | HTTPS traffic | Security groups, Cloudflare |
| **TCP** | 5432 | **L4** (Transport) | PostgreSQL | Security groups, Docker |
| **TCP** | 8000-9100 | **L4** (Transport) | Application services | Docker networking |
| **TCP** | All | **L4** (Transport) | Outbound traffic | Security group egress |

### 1.5 Network Layer (Layer 3)

| Technology | OSI Layer | Configuration | Purpose |
|------------|-----------|---------------|---------|
| **IPv4** | **L3** (Network) | CIDR blocks | IP addressing |
| **VPC** | **L3** (Network) | 10.0.0.0/16 | Network isolation |
| **Subnets** | **L3** (Network) | 10.0.1.0/24 | Network segmentation |
| **Routing Tables** | **L3** (Network) | 0.0.0.0/0 → IGW | Internet routing |
| **Internet Gateway** | **L3** (Network) | IGW | Internet connectivity |

---

##  Part 2: AWS VPC Networking (Terraform)

### 2.1 VPC Configuration

```hcl
# terraform-ec2/main.tf
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"        # IPv4 CIDR block
  enable_dns_hostnames = true                 # DNS resolution
  enable_dns_support   = true                 # DNS support
}
```

**TCP/IP Technologies:**
- **OSI Layer 3 (Network)**: CIDR Block: 10.0.0.0/16 (65,536 IP addresses)
- **OSI Layer 7 (Application)**: DNS - Internal DNS resolution for instances
- **OSI Layer 3 (Network)**: IP Addressing - Automatic IP assignment

### 2.2 Subnet Configuration

```hcl
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"     # 256 IP addresses
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = true              # Public IP assignment
}
```

**TCP/IP Technologies:**
- **OSI Layer 3 (Network)**: Subnetting - 10.0.1.0/24 (256 IPs per subnet)
- **OSI Layer 3 (Network)**: Public IP - Automatic public IP assignment
- **OSI Layer 3 (Network)**: Availability Zone - Network redundancy

### 2.3 Routing Table

```hcl
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"                  # Default route
    gateway_id = aws_internet_gateway.main.id # Internet Gateway
  }
}
```

**TCP/IP Technologies:**
- **OSI Layer 3 (Network)**: Default Route - 0.0.0.0/0 (all traffic)
- **OSI Layer 3 (Network)**: Internet Gateway - Route to internet
- **OSI Layer 3 (Network)**: Routing - IP packet routing

### 2.4 Internet Gateway

```hcl
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}
```

**TCP/IP Technologies:**
- **OSI Layer 3 (Network)**: NAT - Network Address Translation
- **OSI Layer 3 (Network)**: Internet Connectivity - Outbound/inbound traffic
- **OSI Layer 3 (Network)**: Public IP - Internet-facing IP addresses

---

##  Part 3: Security Groups (TCP/UDP Rules)

### 3.1 Inbound Rules (Ingress)

```hcl
# terraform-ec2/main.tf
resource "aws_security_group" "app_server" {
  # HTTP (TCP port 80)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"                      # TCP protocol
    cidr_blocks = ["0.0.0.0/0"]              # All IPv4 addresses
    description = "HTTP from anywhere"
  }

  # HTTPS (TCP port 443)
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"                      # TCP protocol
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS from anywhere"
  }

  # SSH (TCP port 22)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"                      # TCP protocol
    cidr_blocks = var.ssh_allowed_cidrs      # Restricted IPs
    description = "SSH from allowed IPs"
  }
}
```

**TCP/IP Technologies:**
- **OSI Layer 4 (Transport)**: TCP Protocol - Connection-oriented protocol
- **OSI Layer 4 (Transport)**: Port Ranges - Specific port numbers (80, 443, 22)
- **OSI Layer 3 (Network)**: CIDR Blocks - IP address ranges (0.0.0.0/0 = all IPs)
- **OSI Layer 4 (Transport)**: Stateful Firewall - Tracks connection state (L4)

### 3.2 Outbound Rules (Egress)

```hcl
  # Allow all outbound traffic
  egress {
    from_port   = 0                          # All ports
    to_port     = 0                          # All ports
    protocol    = "-1"                       # All protocols (TCP, UDP, ICMP)
    cidr_blocks = ["0.0.0.0/0"]              # All destinations
    description = "Allow all outbound traffic"
  }
```

**TCP/IP Technologies:**
- **OSI Layer 4 (Transport)**: Protocol -1 - All protocols (TCP, UDP, ICMP)
- **OSI Layer 4 (Transport)**: Port 0 - All ports
- **OSI Layer 3/4**: Egress Filtering - Outbound traffic control

---

##  Part 4: Docker Networking

### 4.1 Bridge Network

```yaml
# docker-compose/docker-compose.yml
networks:
  app-network:
    driver: bridge                          # Linux bridge driver
```

**TCP/IP Technologies:**
- **OSI Layer 2 (Data Link)**: Bridge Network - Ethernet bridging
- **OSI Layer 7 (Application)**: Internal DNS - Service name resolution
- **OSI Layer 3 (Network)**: IP Assignment - Automatic IP assignment (172.x.x.x)

### 4.2 Port Mappings

```yaml
caddy:
  ports:
    - "8080:80"                             # Host:Container
    - "8443:443"                            # Host:Container
```

**TCP/IP Technologies:**
- **OSI Layer 4 (Transport)**: Port Mapping - Host port → Container port
- **OSI Layer 3 (Network)**: NAT - Network Address Translation
- **OSI Layer 4 (Transport)**: TCP Forwarding - Port forwarding

### 4.3 Service Discovery (DNS)

```yaml
fastapi-app:
  environment:
    - DB_HOST=postgresql                    # Docker DNS resolution
    - MEILISEARCH_URL=http://meilisearch:7700
    - S3_ENDPOINT_URL=http://minio:9000
```

**TCP/IP Technologies:**
- **OSI Layer 7 (Application)**: DNS Resolution - Service names → IP addresses
- **OSI Layer 7 (Application)**: Internal DNS - Docker's embedded DNS server
- **OSI Layer 7 (Application)**: SRV Records - Service discovery

---

##  Part 5: Network Monitoring & Probes

### 5.1 Blackbox Exporter (TCP Probes)

```yaml
# docker-compose/config/prometheus/prometheus.yml
- job_name: "blackbox-tcp"
  metrics_path: "/probe"
  params:
    module: ["tcp_connect"]                 # TCP connection probe
  static_configs:
    - targets:
        - "postgresql:5432"                 # TCP port 5432
        - "meilisearch:7700"                # TCP port 7700
        - "minio:9000"                      # TCP port 9000
        - "prometheus:9090"                 # TCP port 9090
```

**TCP/IP Technologies:**
- **OSI Layer 4 (Transport)**: TCP Connect - TCP handshake (SYN, SYN-ACK, ACK)
- **OSI Layer 4 (Transport)**: Port Scanning - Port connectivity testing
- **OSI Layer 4 (Transport)**: Network Monitoring - TCP connection health

### 5.2 Blackbox Configuration

```yaml
# docker-compose/config/blackbox/blackbox.yml
modules:
  tcp_connect:
    prober: tcp                             # TCP prober
    timeout: 5s                             # TCP timeout
    tcp:
      preferred_ip_protocol: "ip4"          # IPv4 protocol
      ip_protocol_fallback: false
```

**TCP/IP Technologies:**
- **OSI Layer 4 (Transport)**: TCP Prober - TCP connection testing
- **OSI Layer 3 (Network)**: IPv4 Protocol - Internet Protocol version 4
- **OSI Layer 4 (Transport)**: TCP Timeout - Connection timeout handling
- **OSI Layer 4 (Transport)**: SYN/ACK - TCP handshake process

### 5.3 HTTP Probes (TCP-based)

```yaml
- job_name: "blackbox-http-public"
  params:
    module: ["http_2xx"]                    # HTTP over TCP
  static_configs:
    - targets:
        - "http://caddy:80/"                # HTTP (TCP port 80)
        - "http://caddy:80/health"
```

**TCP/IP Technologies:**
- **OSI Layer 7 (Application)**: HTTP over TCP - Application layer over TCP (L4)
- **OSI Layer 4 (Transport)**: TCP Port 80 - HTTP default port
- **OSI Layer 4 (Transport)**: TCP Port 443 - HTTPS default port
- **OSI Layer 6 (Presentation)**: TLS/SSL - Encryption over TCP

---

##  Part 6: TLS/SSL & Encryption (TCP-based)

### 6.1 TLS Termination

```
Internet → Cloudflare (TLS/SSL) → HTTP (TCP) → Caddy → Services
```

**TCP/IP Technologies:**
- **OSI Layer 6 (Presentation)**: TLS/SSL - Encryption over TCP
- **OSI Layer 5/6 (Session/Presentation)**: TLS Handshake - TCP connection (L4) + TLS negotiation (L6)
- **OSI Layer 6 (Presentation)**: Certificate - X.509 certificates
- **OSI Layer 6 (Presentation)**: Cipher Suites - Encryption algorithms

### 6.2 Cloudflare Tunnel (Encrypted TCP)

```yaml
# docker-compose/docker-compose.yml
cloudflared:
  command: tunnel --no-autoupdate --url http://caddy:80
```

**TCP/IP Technologies:**
- **OSI Layer 4/6 (Transport/Presentation)**: Encrypted Tunnel - TCP connection (L4) with encryption (L6)
- **OSI Layer 4 (Transport)**: Outbound TCP - Outbound-only connection
- **OSI Layer 6 (Presentation)**: TLS/SSL - End-to-end encryption
- **OSI Layer 4/7 (Transport/Application)**: Proxy Protocol - TCP proxying (L4) with application routing (L7)

---

##  Part 7: DNS & Service Discovery

### 7.1 Docker DNS

```yaml
# Services resolve via Docker DNS
DB_HOST=postgresql                          # Resolves to 172.25.0.X
MEILISEARCH_URL=http://meilisearch:7700     # Resolves to 172.25.0.Y
```

**TCP/IP Technologies:**
- **OSI Layer 7 (Application)**: DNS Resolution - Domain name → IP address
- **OSI Layer 7 (Application)**: Internal DNS - Docker's DNS server
- **OSI Layer 7 (Application)**: A Records - IPv4 address records
- **OSI Layer 7 (Application)**: SRV Records - Service discovery records

### 7.2 VPC DNS

```hcl
# terraform-ec2/main.tf
resource "aws_vpc" "main" {
  enable_dns_hostnames = true               # DNS hostname resolution
  enable_dns_support   = true               # DNS support
}
```

**TCP/IP Technologies:**
- **OSI Layer 7 (Application)**: DNS Hostnames - Instance hostname resolution
- **OSI Layer 7 (Application)**: DNS Support - DNS query support
- **OSI Layer 7 (Application)**: Route 53 - AWS DNS service
- **OSI Layer 7 (Application)**: Private DNS - Internal DNS resolution

---

##  Part 8: Network Metrics & Monitoring

### 8.1 Node Exporter (Network Metrics)

```yaml
# docker-compose/docker-compose.yml
node-exporter:
  ports:
    - "9100:9100"                           # TCP port 9100
```

**TCP/IP Metrics (OSI Layers):**
- **OSI Layer 2/3 (Data Link/Network)**: Network I/O - Bytes sent/received
- **OSI Layer 2 (Data Link)**: Network Interfaces - Interface statistics
- **OSI Layer 4 (Transport)**: TCP Connections - Active connections
- **OSI Layer 2/3 (Data Link/Network)**: Network Errors - Packet errors, drops

### 8.2 Prometheus Network Queries

```promql
# Network I/O rate
rate(node_network_receive_bytes_total[5m])

# TCP connections
node_netstat_Tcp_CurrEstab

# Network errors
rate(node_network_receive_errs_total[5m])
```

**TCP/IP Technologies (OSI Layers):**
- **OSI Layer 2/3/4 (Data Link/Network/Transport)**: Network Statistics - `/proc/net` (Linux)
- **OSI Layer 4 (Transport)**: TCP Stats - TCP connection statistics
- **OSI Layer 2 (Data Link)**: Network Interfaces - Interface metrics
- **OSI Layer 2/3 (Data Link/Network)**: Packet Counters - Sent/received packets

---

##  Part 9: Load Balancing & Routing

### 9.1 Reverse Proxy (Layer 7)

```caddyfile
# docker-compose/config/caddy/Caddyfile
:80 {
    handle /api/* {
        reverse_proxy fastapi-app:8000      # TCP forwarding
    }
}
```

**TCP/IP Technologies:**
- **OSI Layer 7 (Application)**: HTTP-based routing
- **OSI Layer 4 (Transport)**: TCP Forwarding - TCP connection forwarding
- **OSI Layer 7 (Application)**: Load Balancing - Multiple backend servers
- **OSI Layer 4/7 (Transport/Application)**: Health Checks - TCP/HTTP health checks

### 9.2 ALB Configuration (Future)

```hcl
# terraform-ec2/main.tf (future)
resource "aws_lb" "main" {
  load_balancer_type = "application"        # Layer 7 load balancer
  protocol          = "HTTPS"               # TCP-based HTTPS
  port              = 443                   # TCP port 443
}
```

**TCP/IP Technologies:**
- **OSI Layer 7 (Application)**: Application Load Balancer - HTTP/HTTPS routing
- **OSI Layer 4 (Transport)**: TCP Load Balancing - TCP connection distribution
- **OSI Layer 4/7 (Transport/Application)**: Health Checks - TCP/HTTP health probes
- **OSI Layer 5 (Session)**: Sticky Sessions - TCP session affinity

---

##  Part 10: Network Troubleshooting Tools

### 10.1 TCP Connection Testing

```bash
# Test TCP connection
nc -zv postgresql 5432                      # TCP port test
telnet postgresql 5432                      # TCP connection test
curl -v http://fastapi-app:8000/health      # HTTP over TCP
```

**TCP/IP Technologies:**
- **OSI Layer 4 (Transport)**: netcat (nc) - TCP connection testing
- **OSI Layer 4 (Transport)**: telnet - TCP connection testing
- **OSI Layer 7 (Application)**: curl - HTTP over TCP (L4)
- **OSI Layer 4 (Transport)**: TCP Handshake - SYN, SYN-ACK, ACK

### 10.2 Network Diagnostics

```bash
# Check network interfaces
ip addr show                                 # IPv4/IPv6 addresses
ip route show                                # Routing table
netstat -tuln                                # TCP/UDP ports
ss -tuln                                     # Socket statistics
```

**TCP/IP Technologies:**
- **OSI Layer 3 (Network)**: IP Addresses - IPv4/IPv6 configuration
- **OSI Layer 3 (Network)**: Routing Table - IP routing
- **OSI Layer 4 (Transport)**: Socket Statistics - TCP/UDP sockets
- **OSI Layer 2/3 (Data Link/Network)**: Network Interfaces - Interface configuration

---

##  Part 11: Network Security

### 11.1 Firewall Rules (UFW)

```bash
# terraform-ec2/user-data.sh
ufw --force enable
ufw default deny incoming                   # Deny all inbound TCP/UDP
ufw default allow outgoing                  # Allow all outbound TCP/UDP
ufw allow 22/tcp                            # Allow SSH (TCP)
ufw allow 80/tcp                            # Allow HTTP (TCP)
ufw allow 443/tcp                           # Allow HTTPS (TCP)
```

**TCP/IP Technologies:**
- **OSI Layer 3/4 (Network/Transport)**: Firewall - Packet filtering
- **OSI Layer 4 (Transport)**: TCP Rules - TCP port rules
- **OSI Layer 4 (Transport)**: UDP Rules - UDP port rules
- **OSI Layer 4 (Transport)**: Stateful Firewall - Connection state tracking

### 11.2 Network Policies (Kubernetes)

```yaml
# k8s/networking/04-network-policies.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
spec:
  policyTypes:
    - Ingress                                 # Inbound traffic
    - Egress                                  # Outbound traffic
  ingress:
    - from:
        - podSelector: {}                     # Allow from pods
      ports:
        - protocol: TCP                       # TCP protocol
          port: 8000                          # TCP port 8000
```

**TCP/IP Technologies:**
- **OSI Layer 3/4 (Network/Transport)**: Network Policies - IP and port filtering
- **OSI Layer 4 (Transport)**: TCP Rules - TCP port filtering
- **OSI Layer 3 (Network)**: Pod Selectors - Network segmentation
- **OSI Layer 3/4 (Network/Transport)**: Ingress/Egress - Inbound/outbound rules

---

##  Part 12: Cloudflare Tunnel (Advanced TCP)

### 12.1 Tunnel Protocol

```yaml
# docker-compose/docker-compose.yml
cloudflared:
  command: tunnel --no-autoupdate --url http://caddy:80
```

**TCP/IP Technologies:**
- **OSI Layer 4 (Transport)**: Outbound TCP - Outbound-only connection
- **OSI Layer 4/6 (Transport/Presentation)**: Tunnel Protocol - Encrypted TCP tunnel
- **OSI Layer 7 (Application)**: WebSocket - TCP-based WebSocket protocol (L4 transport)
- **OSI Layer 7 (Application)**: HTTP/2 - TCP-based HTTP/2 protocol (L4 transport)

### 12.2 Tunnel Architecture

```
Internet → Cloudflare Edge (TCP) → Encrypted Tunnel (TCP) → Caddy (TCP:80)
```

**TCP/IP Technologies:**
- **OSI Layer 4 (Transport)**: TCP Connection - Persistent TCP connection
- **OSI Layer 6 (Presentation)**: TLS Encryption - Encrypted TCP stream (L4)
- **OSI Layer 4/7 (Transport/Application)**: Proxy Protocol - TCP proxying (L4) with application awareness (L7)
- **OSI Layer 4/7 (Transport/Application)**: Load Balancing - TCP load balancing (L4) with HTTP routing (L7)

---

##  Part 13: Network Communication Matrix

### 13.1 Complete TCP/IP Communication Matrix

| Source | Target | Protocol | Port | OSI Layers | Purpose |
|--------|--------|----------|------|------------|---------|
| **User** | Cloudflare | HTTPS | 443 | **L7** (Application) + **L6** (TLS) + **L4** (TCP) | TLS-encrypted HTTP |
| **Cloudflare** | Caddy | HTTP | 80 | **L7** (Application) + **L4** (TCP) | Plain HTTP |
| **Caddy** | FastAPI | HTTP | 8000 | **L7** (Application) + **L4** (TCP) | API requests |
| **FastAPI** | PostgreSQL | PostgreSQL | 5432 | **L7** (Application) + **L4** (TCP) | Database queries |
| **FastAPI** | Meilisearch | HTTP | 7700 | **L7** (Application) + **L4** (TCP) | Search queries |
| **FastAPI** | MinIO | HTTP (S3) | 9000 | **L7** (Application) + **L4** (TCP) | File storage |
| **Prometheus** | FastAPI | HTTP | 9091 | **L7** (Application) + **L4** (TCP) | Metrics scraping |
| **Prometheus** | MinIO | HTTP | 9000 | **L7** (Application) + **L4** (TCP) | Metrics scraping |
| **Prometheus** | Node Exporter | HTTP | 9100 | **L7** (Application) + **L4** (TCP) | Host metrics |
| **Blackbox** | Services | TCP | Various | **L4** (Transport) | Port connectivity |
| **Grafana** | Prometheus | HTTP | 9090 | **L7** (Application) + **L4** (TCP) | Metrics queries |
| **Grafana** | Loki | HTTP | 3100 | **L7** (Application) + **L4** (TCP) | Log queries |
| **Promtail** | Loki | HTTP | 3100 | **L7** (Application) + **L4** (TCP) | Log shipping |
| **Docker DNS** | Services | DNS | 53 | **L7** (Application) + **L4** (UDP/TCP) | Service discovery |
| **VPC Routing** | Internet | IP | - | **L3** (Network) | IP packet routing |
| **Bridge Network** | Containers | Ethernet | - | **L2** (Data Link) | Container networking |

---

##  Part 14: TCP/IP Interview Talking Points

### Key Technologies Demonstrated:

1. **OSI Layer 2 (Data Link)**: Docker bridge networks, Ethernet bridging
2. **OSI Layer 3 (Network)**: VPC, subnets, routing tables, IP addressing, NAT
3. **OSI Layer 4 (Transport)**: TCP/UDP protocols, port management, connection tracking
4. **OSI Layer 5 (Session)**: TCP sessions, TLS sessions, sticky sessions
5. **OSI Layer 6 (Presentation)**: TLS/SSL encryption, certificates, cipher suites
6. **OSI Layer 7 (Application)**: HTTP, HTTPS, PostgreSQL, DNS, REST APIs
7. **Network Security**: Security groups (L3/L4), firewall rules (L3/L4), network policies
8. **Load Balancing**: Reverse proxy (L7), ALB (L7), TCP load balancing (L4)
9. **Network Monitoring**: TCP probes (L4), network metrics (L2/L3/L4), connection tracking
10. **Service Discovery**: DNS resolution (L7), Docker DNS (L7), VPC DNS (L7)

### Interview Elevator Pitch:

"I architected a production-grade networking stack using TCP/IP technologies across all OSI model layers. At Layer 2, I configured Docker bridge networks for container communication. At Layer 3, I designed VPC with CIDR blocks, subnets, routing tables, and NAT. At Layer 4, I implemented TCP/UDP security groups with stateful firewall rules and port management. At Layer 6, I deployed TLS/SSL encryption with certificate management. At Layer 7, I deployed HTTP/HTTPS reverse proxy with TLS termination, PostgreSQL database connections, and DNS-based service discovery. I implemented network monitoring with TCP probes, encrypted tunnels with Cloudflare, and load balancing with reverse proxy. The stack demonstrates comprehensive expertise across the entire OSI model stack, from physical networking to application protocols."

---

##  Summary

### TCP/IP Technologies Covered (by OSI Layer):

 **Layer 2 (Data Link)**: Docker bridge networks, Ethernet bridging  
 **Layer 3 (Network)**: VPC, subnets, routing, IP addressing, NAT  
 **Layer 4 (Transport)**: TCP, UDP, ports, connection tracking  
 **Layer 5 (Session)**: TCP sessions, TLS sessions, session management  
 **Layer 6 (Presentation)**: TLS/SSL encryption, certificates, cipher suites  
 **Layer 7 (Application)**: HTTP, HTTPS, PostgreSQL, DNS, REST APIs  
 **Network Security**: Security groups (L3/L4), firewalls (L3/L4), network policies  
 **Load Balancing**: Reverse proxy (L7), ALB (L7), TCP load balancing (L4)  
 **Network Monitoring**: TCP probes (L4), network metrics (L2/L3/L4)  
 **Service Discovery**: DNS resolution (L7), Docker DNS (L7), VPC DNS (L7)  
 **Encryption**: TLS/SSL (L6), encrypted tunnels (L4/L6)  
 **Troubleshooting**: Network diagnostics, TCP testing  

### Files with TCP/IP Configurations:

- `terraform-ec2/main.tf` - VPC, subnets, security groups
- `docker-compose/docker-compose.yml` - Port mappings, networks
- `docker-compose/config/caddy/Caddyfile` - Reverse proxy routing
- `docker-compose/config/prometheus/prometheus.yml` - TCP probes
- `docker-compose/config/blackbox/blackbox.yml` - TCP monitoring
- `terraform-ec2/user-data.sh` - Firewall rules (UFW)

---

**This repository demonstrates comprehensive TCP/IP networking expertise across all layers of the protocol stack!** 

