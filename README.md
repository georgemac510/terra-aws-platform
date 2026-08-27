# Pass two: the same platform on AWS

Same three containers, now running on an EC2 instance inside a VPC you also
define in Terraform.

## What maps to what

| Local (pass one)        | AWS (pass two)                          |
|-------------------------|------------------------------------------|
| `docker_network`        | `aws_vpc` + subnet + route table + IGW   |
| "don't publish 5432"    | `aws_security_group` rules               |
| `docker_container`      | one `aws_instance` running all three     |
| `docker_volume`         | `root_block_device` (EBS)                |
| `docker_image` build    | `docker compose build`, on the instance  |
| provider `docker {}`    | provider `aws { region }`                |

Terraform now stops at the instance boundary. It creates the machine and hands
it a startup script; everything above that line is Docker's job. That split is
the thing to notice.

## Before you start

1. **Set a billing alarm.** Billing console -> Budgets -> a $5 monthly budget
   with an email alert. Do this first.
2. **Configure credentials.** `aws configure`, or export `AWS_ACCESS_KEY_ID`
   and `AWS_SECRET_ACCESS_KEY`. Verify with `aws sts get-caller-identity`.
3. **Push the app to GitHub.** The instance clones it over public HTTPS, so
   the repo must be public. It needs `docker-compose.yml` at the root and the
   `services/api` and `services/web` directories from pass one. Copy the
   `docker-compose.yml` in this folder into that repo.

## Run it

    cp terraform.tfvars.example terraform.tfvars    # edit all three values
    curl -s https://checkip.amazonaws.com           # your IP, for ssh_cidr
    terraform init
    terraform plan
    terraform apply

Apply returns in under a minute, but the site is NOT up yet. Cloud-init is
still installing Docker and building images, which takes another 2-4 minutes.
Watch it:

    terraform output -raw boot_log      # prints the command
    ssh ubuntu@<ip> 'sudo tail -f /var/log/cloud-init-output.log'

When `/var/log/platform-ready` exists, open `terraform output -raw web_url`.

## Tear it down

    terraform destroy

Do this at the end of every session. Left running, this costs roughly two
cents an hour: t3.micro ~$7.60/month, 20GB gp3 ~$1.60/month, and the public
IPv4 address ~$3.60/month. Stopping the instance does NOT stop the EBS or IP
charges. Destroying does.

Afterwards, confirm nothing lingers: EC2 instances, volumes, Elastic IPs.
Terraform only destroys what it created, so anything you made by hand in the
console stays and keeps billing.

## Things worth noticing

**`user_data` runs once.** Only on first boot. Editing the script and applying
again replaces the whole instance, which is why you should treat it as
bootstrap and not as a deploy mechanism.

**Deploying code means SSH.** To ship a change you log in and run
`git pull && docker compose up -d --build`. That works for one box and falls
apart past that, which is the argument for ECR plus GitHub Actions later.

**`data "aws_ami"` reads, it does not create.** With `most_recent = true`,
Canonical publishing a new image can silently force instance replacement on a
future apply. Production configs pin the AMI id.

**Compose's `depends_on` is stronger than Terraform's.** The
`condition: service_healthy` clause genuinely waits for Postgres to pass its
healthcheck. Terraform's `depends_on` only orders creation. Same words,
different guarantees.

**No load balancer, no TLS, no autoscaling.** One instance, plain HTTP. Adding
an ALB is the natural next step and costs about $16/month, which is why it
isn't here.
