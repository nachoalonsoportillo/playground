# Get current public IP.
data "http" "current_public_ip" {
  url = "http://ipinfo.io/json"
  request_headers = {
    Accept = "application/json"
  }
}

# Helper to figure out whether we're running on Windows or Linux.
data "external" "os" {
  working_dir = path.module
  program     = ["printf", "{\"os\": \"linux\"}"]
}
