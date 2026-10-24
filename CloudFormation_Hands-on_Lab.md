# Hands-on Lab: Deploy, Update and Delete a Stack with AWS CloudFormation

**Course:** DevOps on AWS – Intermediate
**Duration:** about 70 minutes
**Goal:** Write a CloudFormation template with parameters and outputs, deploy it as a stack, update it safely using a change set, and delete it (including fixing a delete failure).

---

## What you will build

A simple stack containing:

| Resource | Purpose |
|---|---|
| S3 bucket | Storage for application files |
| Security group | Allows HTTP (port 80) to the web server |
| EC2 instance | Amazon Linux web server that serves a simple page |

```
Template (YAML) ──► CloudFormation ──► Stack ──► S3 bucket + Security group + EC2 web server
      ▲                                  │
  Parameters                          Outputs (bucket name, URL)
```

## Key concepts (quick reference)

| Term | Meaning |
|---|---|
| Template | JSON or YAML file that describes your resources |
| Stack | One deployed instance of a template, managed as a single unit |
| Resource | An AWS object created by the stack (bucket, instance, and so on) |
| Parameter | An input value supplied when the stack is created or updated |
| Output | A value the stack exposes after deployment (for example a URL) |
| Change set | A preview of what an update will do before you apply it |
| Rollback | Automatic undo when a create or update fails |

## Prerequisites

- AWS Console access with permission for CloudFormation, S3, EC2 and SSM parameter read
- A **default VPC** in your chosen region (the template uses it, to keep the lab simple)
- Same AWS region for the whole lab

> Cost note: the lab uses a `t3.micro` instance and an empty S3 bucket. Delete the stack at the end to avoid charges.

---

## Step 1: Write the template

Create a file named **`simple-stack.yaml`** with this content:

```yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: Simple stack - S3 bucket, security group and web server

Parameters:
  EnvironmentName:
    Type: String
    Default: dev
    AllowedValues: [dev, test, prod]
    Description: Environment name used in tags and the web page

  InstanceType:
    Type: String
    Default: t3.micro
    AllowedValues: [t3.micro, t3.small]
    Description: EC2 instance type

  LatestAmiId:
    Type: AWS::SSM::Parameter::Value<AWS::EC2::Image::Id>
    Default: /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64
    Description: Latest Amazon Linux 2023 AMI (read from SSM Parameter Store)

Resources:
  AppBucket:
    Type: AWS::S3::Bucket
    Properties:
      Tags:
        - Key: Environment
          Value: !Ref EnvironmentName

  WebSecurityGroup:
    Type: AWS::EC2::SecurityGroup
    Properties:
      GroupDescription: Allow HTTP from anywhere
      SecurityGroupIngress:
        - IpProtocol: tcp
          FromPort: 80
          ToPort: 80
          CidrIp: 0.0.0.0/0
      Tags:
        - Key: Environment
          Value: !Ref EnvironmentName

  WebServer:
    Type: AWS::EC2::Instance
    Properties:
      ImageId: !Ref LatestAmiId
      InstanceType: !Ref InstanceType
      SecurityGroupIds:
        - !GetAtt WebSecurityGroup.GroupId
      Tags:
        - Key: Name
          Value: !Sub '${EnvironmentName}-web-server'
        - Key: Environment
          Value: !Ref EnvironmentName
      UserData:
        Fn::Base64: !Sub |
          #!/bin/bash
          dnf install -y httpd
          systemctl enable --now httpd
          echo "<h1>Hello from ${EnvironmentName} - deployed with CloudFormation</h1>" > /var/www/html/index.html

Outputs:
  BucketName:
    Description: Name of the S3 bucket
    Value: !Ref AppBucket

  WebsiteURL:
    Description: URL of the web server
    Value: !Sub 'http://${WebServer.PublicIp}'

  InstanceId:
    Description: ID of the EC2 instance
    Value: !Ref WebServer
```

**Read the template together**

| Section | What it does |
|---|---|
| `Parameters` | Makes the template reusable: environment, instance type, AMI |
| `Resources` | The AWS objects to create (required section) |
| `!Ref` | Returns a parameter value or a resource ID |
| `!GetAtt` | Reads an attribute of a resource (for example the security group ID) |
| `!Sub` | Substitutes `${...}` variables inside a string |
| `Outputs` | Values shown after the stack is created |

Notice that the bucket has no fixed name. CloudFormation generates a unique one, so the template can be deployed more than once.

---

## Step 2: Validate and create the stack

### 2.1 Validate (optional but recommended)

With the AWS CLI:

```bash
aws cloudformation validate-template --template-body file://simple-stack.yaml
```

### 2.2 Create the stack in the console

1. Open the **CloudFormation** console and choose **Create stack**, then **With new resources (standard)**.
2. **Prepare template:** **Choose an existing template**
3. **Specify template:** **Upload a template file**, then choose `simple-stack.yaml`, then **Next**.
4. **Stack name:** `demo-stack`
5. **Parameters:** keep the defaults (`dev`, `t3.micro`, latest AMI), then **Next**.
6. **Configure stack options:** add a tag `Project = cloudformation-lab`. Keep **Roll back all stack resources** on failure. Choose **Next**.
7. Review and choose **Submit**.

### 2.3 Same thing from the CLI (optional)

```bash
aws cloudformation create-stack \
  --stack-name demo-stack \
  --template-body file://simple-stack.yaml \
  --parameters ParameterKey=EnvironmentName,ParameterValue=dev
```

---

## Step 3: Check resources, events and outputs

Open the stack and go through each tab:

| Tab | What to look for |
|---|---|
| **Events** | Resources moving through `CREATE_IN_PROGRESS` to `CREATE_COMPLETE`, newest at the top |
| **Resources** | The bucket, security group and instance, with their physical IDs |
| **Outputs** | `BucketName`, `WebsiteURL`, `InstanceId` |
| **Parameters** | The values used |
| **Template** | The template that was deployed |

Wait until the stack status is **CREATE_COMPLETE** (usually 2 to 3 minutes).

Open the `WebsiteURL` value in a browser. After a minute for the web server to start, you should see:

> Hello from dev - deployed with CloudFormation

**Checkpoint 1:** Stack is `CREATE_COMPLETE` and the web page loads.

---

## Step 4: Update the stack

Always **preview** an update before applying it. CloudFormation tells you what changes and whether a resource is modified in place or replaced.

### Update A: Change parameters

1. Open `demo-stack`, choose **Update**, then **Make a direct update** (or **Create a change set** for the preview, covered in Update B).
2. Choose **Use existing template**, then **Next**.
3. Change `EnvironmentName` to `test` and `InstanceType` to `t3.small`, then **Next**.
4. Continue to the review page and review the **Change set preview**:

| Resource | Action | Replacement |
|---|---|---|
| AppBucket | Modify | False |
| WebSecurityGroup | Modify | False |
| WebServer | Modify | Conditional or False |

5. Choose **Submit** and watch the **Events** tab until `UPDATE_COMPLETE`.

> Changing the instance type stops and starts the instance, so its public IP can change. Check the **Outputs** tab for the new `WebsiteURL`.

### Update B: Change the template with a change set

1. In `simple-stack.yaml`, add versioning to the bucket:

```yaml
  AppBucket:
    Type: AWS::S3::Bucket
    Properties:
      VersioningConfiguration:
        Status: Enabled
      Tags:
        - Key: Environment
          Value: !Ref EnvironmentName
```

2. In the console choose **Stack actions**, then **Create change set for current stack**.
3. **Replace existing template**, upload the edited file, keep the parameters, and **Next** through to **Submit**.
4. Name the change set `enable-versioning` and open it when it is ready.
5. Check that only `AppBucket` shows **Modify** (Replacement: False), then choose **Execute change set**.

**CLI equivalent:**

```bash
aws cloudformation create-change-set \
  --stack-name demo-stack \
  --change-set-name enable-versioning \
  --template-body file://simple-stack.yaml \
  --parameters ParameterKey=EnvironmentName,UsePreviousValue=true \
               ParameterKey=InstanceType,UsePreviousValue=true \
               ParameterKey=LatestAmiId,UsePreviousValue=true

aws cloudformation describe-change-set \
  --stack-name demo-stack --change-set-name enable-versioning

aws cloudformation execute-change-set \
  --stack-name demo-stack --change-set-name enable-versioning
```

**Checkpoint 2:** Stack shows `UPDATE_COMPLETE` after both updates, and the bucket now has versioning enabled.

---

## Step 5: Trigger a failed update (rollback practice)

1. Edit the template and change the instance resource's `InstanceType` to a hard-coded invalid value:

```yaml
      InstanceType: t3.imaginary
```

2. Update the stack with the edited template.
3. Watch the **Events** tab: the update fails, the status goes to `UPDATE_ROLLBACK_IN_PROGRESS`, and finally `UPDATE_ROLLBACK_COMPLETE`.
4. Find the failure reason in the **Events** tab (the first `UPDATE_FAILED` event).

> Key point: when an update fails, CloudFormation rolls the stack back to its last working state.

---

## Step 6: Delete the stack (and handle the failure)

### 6.1 Make the delete fail on purpose

1. Open the S3 console and open the bucket named in the stack **Outputs**.
2. Upload any small file (for example `test.txt`).
3. Go back to CloudFormation, select `demo-stack`, and choose **Delete**, then confirm.
4. The stack ends in **DELETE_FAILED**. Open **Events** and find the reason: the bucket is not empty.

### 6.2 Fix it and delete again

1. In S3, choose the bucket, then **Empty** (versioning is enabled, so this removes all versions).
2. Back in CloudFormation, choose **Delete** again.
3. Watch all resources move to `DELETE_COMPLETE`, then the stack disappears from the list (filter by **Deleted** to see it).

**CLI equivalent:**

```bash
aws cloudformation delete-stack --stack-name demo-stack
aws cloudformation wait stack-delete-complete --stack-name demo-stack
```

**Checkpoint 3:** The stack and all its resources are gone.

---

## Optional: Drift detection

Drift means someone changed a resource outside CloudFormation.

1. Re-create the stack (Step 2).
2. In the EC2 console, edit a tag on the instance.
3. In CloudFormation choose **Stack actions**, then **Detect drift**.
4. After it finishes choose **View drift results** and compare expected and actual values.

## Optional: Protect a resource from deletion

Add a deletion policy to keep the bucket when the stack is deleted:

```yaml
  AppBucket:
    Type: AWS::S3::Bucket
    DeletionPolicy: Retain
```

With `Retain`, the bucket stays after stack deletion. Delete it manually afterwards.

---

## Troubleshooting guide

| Symptom | Likely cause | Fix |
|---|---|---|
| `ROLLBACK_COMPLETE` right after create | A resource failed to create | Read the first `CREATE_FAILED` event, fix the template, delete the stack, and create it again |
| `Template format error` | YAML indentation or syntax | Run `validate-template` and check spacing |
| `Parameter validation failed` | Value not in `AllowedValues` | Use one of the listed values |
| `No default VPC` error | Region has no default VPC | Use another region or add VPC and subnet parameters |
| Web page does not load | Instance still starting, or security group issue | Wait a minute, check the security group allows port 80 |
| `DELETE_FAILED` on the bucket | Bucket not empty | Empty the bucket and delete the stack again |
| `UPDATE_ROLLBACK_FAILED` | Rollback could not complete | Fix the cause, then **Continue update rollback** |
| `AccessDenied` | Missing IAM permission | Add the missing permission to your user or role |

### Useful AWS CLI commands

```bash
aws cloudformation describe-stacks --stack-name demo-stack

aws cloudformation describe-stack-events --stack-name demo-stack \
  --query 'StackEvents[?contains(ResourceStatus, `FAILED`)].[LogicalResourceId,ResourceStatusReason]'

aws cloudformation list-stack-resources --stack-name demo-stack
```

---

## Review questions

1. What is the difference between a template and a stack?
2. Why use parameters instead of hard-coding values?
3. What is a change set and why use one?
4. What does CloudFormation do when a stack update fails?
5. Why did deleting the stack fail while the bucket contained a file?
6. What do `!Ref`, `!Sub` and `!GetAtt` do?

<details>
<summary>Suggested answers</summary>

1. A template is the file that describes resources. A stack is a deployed instance of a template, and one template can create many stacks.
2. Parameters make one template reusable for different environments and sizes without editing the file.
3. A change set previews the effect of an update (modify, replace, remove) before you apply it, so there are no surprises.
4. It rolls the stack back to its last known working state.
5. CloudFormation cannot delete an S3 bucket that still contains objects. Empty the bucket and delete again.
6. `!Ref` returns a parameter value or resource ID, `!Sub` substitutes variables into a string, and `!GetAtt` reads an attribute of a resource.

</details>

---

## Cleanup (avoid charges)

1. Delete `demo-stack` (empty the bucket first if it contains files).
2. Delete any stacks created in the optional exercises.
3. Delete any retained S3 buckets manually.
4. Confirm no stray EC2 instances remain in the EC2 console.

## Lab completion checklist

- [ ] Template written with parameters, resources and outputs
- [ ] Stack created and reached `CREATE_COMPLETE`
- [ ] Web page loaded using the `WebsiteURL` output
- [ ] Stack updated with new parameters
- [ ] Template update applied through a change set
- [ ] Failed update observed and rolled back
- [ ] Delete failure diagnosed, bucket emptied, stack deleted
- [ ] (Optional) Drift detected

## Key takeaways

- A **template** describes the infrastructure, and a **stack** is the running result.
- **Parameters** make templates reusable; **outputs** give you the results.
- Use **change sets** to preview updates before applying them.
- A failed create or update **rolls back** automatically; the **Events** tab shows why.
- Everything is in a file, so infrastructure can be versioned, reviewed and rebuilt at will.
