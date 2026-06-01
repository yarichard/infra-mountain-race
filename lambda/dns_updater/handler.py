import boto3
import os

ECS_CLUSTER     = "mountain-race"
HOSTED_ZONE_ID  = os.environ["HOSTED_ZONE_ID"]
ORIGIN_HOSTNAME = os.environ["ORIGIN_HOSTNAME"]  # "origin.mountain-race.eravest.fr."

ecs = boto3.client("ecs", region_name="eu-west-3")
ec2 = boto3.client("ec2", region_name="eu-west-3")
r53 = boto3.client("route53")


def handler(event, context):
    detail = event.get("detail", {})
    if detail.get("lastStatus") != "RUNNING":
        print(f"Task status is {detail.get('lastStatus')}, skipping")
        return

    task_arn = detail["taskArn"]
    print(f"Task RUNNING: {task_arn}")

    tasks = ecs.describe_tasks(cluster=ECS_CLUSTER, tasks=[task_arn])["tasks"]
    if not tasks:
        raise ValueError(f"Task not found: {task_arn}")

    eni_id = None
    for att in tasks[0].get("attachments", []):
        if att.get("type") == "ElasticNetworkInterface":
            for d in att.get("details", []):
                if d["name"] == "networkInterfaceId":
                    eni_id = d["value"]
                    break

    if not eni_id:
        raise ValueError("No ENI found on task")

    ifaces    = ec2.describe_network_interfaces(NetworkInterfaceIds=[eni_id])["NetworkInterfaces"]
    public_ip = ifaces[0]["Association"]["PublicIp"]
    print(f"Public IP: {public_ip}")

    r53.change_resource_record_sets(
        HostedZoneId=HOSTED_ZONE_ID,
        ChangeBatch={
            "Changes": [{
                "Action": "UPSERT",
                "ResourceRecordSet": {
                    "Name": ORIGIN_HOSTNAME,
                    "Type": "A",
                    "TTL": 60,
                    "ResourceRecords": [{"Value": public_ip}],
                },
            }]
        },
    )
    print(f"Route53 updated: {ORIGIN_HOSTNAME} -> {public_ip}")
