# Day 3 Hands-on Lab: Automated Build with AWS CodeBuild

**Course:** DevOps on AWS – Intermediate
**Duration:** about 45 minutes
**Goal:** Run an automated build (install, test, package) for a ready-made Node.js application using AWS CodeBuild, and store the output as an artifact in S3.

---

## What you will build

```
Your GitHub fork ──► CodeBuild project ──► install → test → build ──► Artifact (zip) in S3
                            │
                            └──► Logs in CloudWatch
```

## Prerequisites

- An AWS account with permission to use CodeBuild, S3, IAM and CloudWatch Logs
- A GitHub account
- AWS Console access (choose one region and use it for everything)
- Optional, for running locally: Git and Node.js 18 or later

---

## Step 1: Get the code (fork the repository)

The sample application is already prepared for you. You do not need to write any code.

1. Open the course repository: `https://github.com/muralikrishna188/AWS-DevOps`
2. Choose **Fork** (top right), then **Create fork**. This creates a copy under your own GitHub account.
3. In your fork, confirm these files are in the root of the `main` branch:

| File | Purpose |
|---|---|
| `app.js` | Sample Node.js application (`add` and `greet` functions) |
| `app.test.js` | Unit tests run during the build |
| `package.json` | Scripts: `start`, `test`, `build` |
| `package-lock.json` | Locked dependency list, required by `npm ci` |
| `buildspec.yml` | The build recipe that CodeBuild follows |

> **Why fork?** CodeBuild needs a repository you own so it can connect to it and, later, receive webhooks. You cannot connect to someone else's repository.

---

## Step 2: Understand the buildspec file

Open `buildspec.yml` in your fork and read it before running anything.

```yaml
version: 0.2

phases:
  install:
    runtime-versions:
      nodejs: 20
    commands:
      - echo "Node version:" && node --version
  pre_build:
    commands:
      - echo "Installing dependencies..."
      - npm ci
  build:
    commands:
      - echo "Running tests..."
      - npm test
      - echo "Packaging the application..."
      - npm run build
  post_build:
    commands:
      - echo "Build completed on $(date)"

artifacts:
  files:
    - '**/*'
  base-directory: dist
  name: codebuild-demo-$(date +%Y-%m-%d)

cache:
  paths:
    - 'node_modules/**/*'
```

| Section | Purpose |
|---|---|
| `version: 0.2` | buildspec format version (use 0.2) |
| `install` | Set the runtime and install build tools |
| `pre_build` | Prepare: install dependencies |
| `build` | Main work: run tests, then package |
| `post_build` | Final steps (notifications, cleanup) |
| `artifacts` | Which files to upload, and from which folder |
| `cache` | Folders reused between builds to save time |

> If any command in `install`, `pre_build` or `build` fails, the build stops and is marked **FAILED**.

**Quick check:** Which phase runs the tests? Which folder becomes the artifact?

---

## Step 3 (optional): Run it locally first

If you have Git and Node.js installed, confirm the app works on your machine.

```bash
git clone https://github.com/<your-username>/AWS-DevOps.git
cd AWS-DevOps
npm ci           # installs from package-lock.json (there are no dependencies)
npm test         # both tests should pass
npm run build    # creates the dist/ folder with app.js and package.json
```

If you skip this step, CodeBuild will do the same work for you in Step 6.

---

## Step 4: Create an S3 bucket for artifacts

1. Open the **S3** console and choose **Create bucket**.
2. Bucket name: `codebuild-demo-artifacts-<your-initials>-<random-number>` (names must be globally unique).
3. Keep **Block all public access** enabled.
4. Choose **Create bucket**.

---

## Step 5: Create the CodeBuild project

1. Open the **CodeBuild** console and choose **Create build project**.
2. **Project configuration**
   - Project name: `codebuild-demo`
3. **Source**
   - Source provider: **GitHub**
   - Connect using OAuth or a GitHub App when prompted, then choose **Repository in my GitHub account** and select your fork, `AWS-DevOps`
   - Source version: `main`
4. **Environment**
   - Provisioning model: **On-demand**
   - Environment image: **Managed image**
   - Compute: **EC2**
   - Operating system: **Amazon Linux**
   - Runtime: **Standard**
   - Image: the latest `aws/codebuild/amazonlinux-...-standard` image available
   - Service role: **New service role** (accept the suggested name)
5. **Buildspec**
   - Choose **Use a buildspec file** and leave the name blank (it defaults to `buildspec.yml` in the repo root)
6. **Artifacts**
   - Type: **Amazon S3**
   - Bucket name: the bucket from Step 4
   - Artifacts packaging: **Zip**
7. **Logs**
   - Keep **CloudWatch logs** enabled
8. Choose **Create build project**.

---

## Step 6: Run the build

1. Open the `codebuild-demo` project and choose **Start build**, then **Start build now**.
2. Open the build run and watch the **Phase details** tab. You should see:

| Phase | Expected status |
|---|---|
| SUBMITTED, QUEUED, PROVISIONING | Succeeded |
| DOWNLOAD_SOURCE | Succeeded |
| INSTALL | Succeeded |
| PRE_BUILD | Succeeded |
| BUILD | Succeeded |
| POST_BUILD | Succeeded |
| UPLOAD_ARTIFACTS | Succeeded |

3. Open the **Build logs** tab and find these lines:

```
Node version:
v20.x.x
...
✔ add returns the sum
✔ greet returns a greeting
...
Build completed on ...
```

**Checkpoint 1:** Your first build shows status **Succeeded**.

---

## Step 7: Verify the artifact

1. Open the S3 bucket from Step 4.
2. Find the zip file (named `codebuild-demo-<date>`).
3. Download and unzip it. You should see `app.js` and `package.json` (the contents of `dist/`).

**Checkpoint 2:** The artifact is visible in S3 and contains the expected files.

---

## Step 8: Break the build and fix it (troubleshooting practice)

You can make these edits directly on GitHub: open the file in your fork, choose the pencil icon, edit, then **Commit changes** to `main`.

### Experiment A: Failing test

1. In `app.test.js`, change the expected value:

```javascript
assert.strictEqual(add(2, 3), 6);   // wrong on purpose
```

2. Commit the change, then **Start build** again in CodeBuild.
3. The build fails in the **BUILD** phase. Open **Build logs** and find the failing assertion (expected 6, actual 5).
4. Fix the test (change 6 back to 5), commit, and rebuild. It should succeed.

### Experiment B: Wrong buildspec

1. In `buildspec.yml`, change `npm run build` to `npm run biuld`.
2. Commit and rebuild. Read the log message ("Missing script").
3. Fix the typo, commit, and rebuild.

### Common failures and fixes

| Symptom | Likely cause | Fix |
|---|---|---|
| `YAML_FILE_ERROR` | Wrong indentation or file name | Check `buildspec.yml` spacing and location |
| `npm ci` fails: no lock file | `package-lock.json` missing from the repo | Run `npm install` locally and commit the lock file |
| `Unsupported runtime` | Runtime version not in the chosen image | Use a supported `nodejs` version or a newer image |
| Failure in `UPLOAD_ARTIFACTS` | Wrong `base-directory` or empty folder | Confirm `dist/` is created by the build phase |
| `AccessDenied` on S3 or logs | Service role missing permissions | Add the needed permission to the CodeBuild service role |
| Build never starts, source error | GitHub connection issue | Reconnect the GitHub credentials in the project source settings |

---

## Step 9 (optional): Automate builds on every push

1. Edit the project, then **Source**, then **Primary source webhook events**.
2. Enable **Rebuild every time a code change is pushed to this repository**.
3. Event type: **PUSH**, branch filter: `^refs/heads/main$`.
4. Save, then commit a small change in your fork (for example, edit the greeting text in `app.js` and update the matching test) and watch a build start automatically.

## Step 10 (optional): Start a build from the AWS CLI

```bash
aws codebuild start-build --project-name codebuild-demo

aws codebuild batch-get-builds --ids <build-id> \
  --query 'builds[0].{status:buildStatus,phase:currentPhase}'
```

---

## Cleanup (avoid charges)

1. Delete the CodeBuild project `codebuild-demo`.
2. Empty and delete the S3 artifact bucket.
3. Delete the CloudWatch log group `/aws/codebuild/codebuild-demo`.
4. Delete the CodeBuild service role in IAM if you no longer need it.

---

## Lab completion checklist

- [ ] Repository forked to your GitHub account
- [ ] `buildspec.yml` reviewed and understood
- [ ] CodeBuild project created and connected to your fork
- [ ] First build **Succeeded**
- [ ] Artifact zip found in S3
- [ ] Failing build diagnosed from logs and fixed
- [ ] (Optional) Webhook triggers a build on push

## Key takeaways

- A **build project** defines source, environment, buildspec and artifacts.
- The **buildspec** is the build recipe and lives in your repository.
- A **failed command or test fails the build**, which is the point of CI.
- **Logs** (phase details and CloudWatch) are the first place to look when troubleshooting.
- **Artifacts** in S3 give you a single, repeatable package to deploy later.
