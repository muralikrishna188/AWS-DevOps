# Hands-on Lab: CI/CD Pipeline with AWS CodePipeline


## What you will build

```
Developer push ──► GitHub ──► [Source stage] ──► [Build stage] ──► [Deploy stage]
                                  │                  │                  │
                             SourceArtifact      CodeBuild          Amazon S3
                                              (buildspec.yml)    (deploy bucket)
```

## Key concepts (quick reference)

| Term | Meaning |
|---|---|
| Pipeline | The complete release workflow |
| Stage | A logical group of actions (Source, Build, Deploy) |
| Action | A single task inside a stage (get source, run build, deploy) |
| Artifact | Files passed from one action to the next, stored in an S3 artifact bucket |
| Transition | The link between stages (can be disabled) |
| Execution | One run of the pipeline, started by a trigger |
| Service role | IAM role that lets CodePipeline call other AWS services |

## Prerequisites

- The `codebuild-demo` GitHub repository from the CodeBuild lab (sample app, `package.json`, `app.js`, `app.test.js`, `buildspec.yml`)
- The `codebuild-demo` CodeBuild project from the CodeBuild lab
- AWS Console access with permission for CodePipeline, CodeBuild, S3, IAM and CodeConnections
- Same AWS region for all resources

---

## Step 1: Prepare the repository, build project and deploy bucket

### 1.1 Check the buildspec

Your `buildspec.yml` should produce the files to deploy from the `dist` folder:

```yaml
version: 0.2

phases:
  install:
    runtime-versions:
      nodejs: 20
  pre_build:
    commands:
      - npm ci
  build:
    commands:
      - npm test
      - npm run build

artifacts:
  files:
    - '**/*'
  base-directory: dist
```

When CodeBuild runs inside a pipeline, CodePipeline controls where the artifact goes. The S3 artifact settings in the CodeBuild project are overridden, so no change is needed there.

### 1.2 Create the deploy bucket

1. Open the **S3** console and choose **Create bucket**.
2. Name: `pipeline-demo-deploy-<your-initials>-<random-number>`
3. Keep **Block all public access** enabled.
4. Choose **Create bucket**.

**Checkpoint 1:** Repo, CodeBuild project and deploy bucket are ready.

---

## Step 2: Start creating the pipeline

1. Open the **CodePipeline** console and choose **Create pipeline**.
2. Choose **Build custom pipeline**, then **Next**.
3. **Pipeline settings**
   - Pipeline name: `codebuild-demo-pipeline`
   - Pipeline type: **V2**
   - Execution mode: **Queued** (or **Superseded**; )
   - Service role: **New service role** (accept the suggested name)
4. Choose **Next**.

## Pipeline settings: execution mode

The execution mode decides what happens when a new pipeline run starts while an earlier run is still in progress (for example, when you push two commits within a minute).

| Mode | Behavior | Best for |
|---|---|---|
| **Superseded** | A newer run overtakes older ones. Waiting runs are dropped, so only the latest commit continues. | Typical CI/CD where only the newest code matters |
| **Queued** | Runs go through in the order they were triggered, one after another, and none are skipped. | When every commit must be built and deployed in order |
| **Parallel** | Runs start independently and at the same time, with no ordering. | Independent builds or tests where order doesn't matter |


---

## Step 3: Add the source stage (with commit trigger)

1. **Source provider:** **GitHub (via GitHub App)**
2. **Connection:** choose **Connect to GitHub**, name it `github-demo-connection`, install or authorize the AWS Connector for GitHub app, and choose your account/repository access.
3. Back in the wizard, select the connection.
4. **Repository name:** `<your-username>/codebuild-demo`
5. **Default branch:** `main`
6. **Output artifact format:** **CodePipeline default**
7. **Trigger:** keep **Start the pipeline on source code change** selected.
8. Choose **Next**.

> If the connection shows **Pending**, finish the authorization in the connection settings first. A pending connection is the most common reason a Source stage fails.

---

## Step 4: Add the build stage

1. **Build provider:** **Other build providers**, then **AWS CodeBuild**
2. **Project name:** `codebuild-demo`
3. **Build type:** **Single build**
4. Choose **Next**.
5. **Test stage:** choose **Skip test stage** (tests already run inside the buildspec).

---

## Step 5: Add the deploy stage

1. **Deploy provider:** **Amazon S3**
2. **Region:** your region
3. **Bucket:** the deploy bucket from Step 1.2
4. Check **Extract file before deploy** (so the files land in the bucket instead of a zip).
5. Choose **Next**.
6. Review the settings and choose **Create pipeline**.

The pipeline starts running immediately.

---

## Step 6: Watch the first run

On the pipeline page you will see three stages. Watch each one:

| Stage | What happens | Expected result |
|---|---|---|
| Source | CodePipeline downloads the code from GitHub | Succeeded |
| Build | CodeBuild installs, tests and packages | Succeeded |
| Deploy | Files copied to the S3 deploy bucket | Succeeded |

Choose **View details** on the Build action to open the CodeBuild logs.

**Checkpoint 2:** All three stages show **Succeeded**.

Open the deploy bucket and confirm `app.js` and `package.json` are there.

---

## Step 7: Trigger the pipeline with a commit

1. In `app.js`, change the greeting:

```javascript
function greet(name) {
  return `Hello from the pipeline, ${name}!`;
}
```

2. Update the matching test in `app.test.js`:

```javascript
assert.strictEqual(greet('Murali'), 'Hello from the pipeline, Murali!');
```

3. Commit and push:

```bash
git add .
git commit -m "Change greeting"
git push origin main
```

4. Open the pipeline. A **new execution** starts within a few moments, without you clicking anything.
5. After it succeeds, download `app.js` from the deploy bucket and confirm it has the new greeting.

**Checkpoint 3:** A push to `main` automatically produced a new deployment.

---

## Step 8: Break the pipeline and fix it

### Experiment A: Failing test stops the pipeline

1. Change the greeting in `app.js` again but do **not** update the test.
2. Push the commit.
3. The **Build** stage fails and the **Deploy** stage does not run.
4. Choose **View details** on the failed Build action, read the CodeBuild log, and find the failing assertion.
5. Fix the test, push, and confirm a new execution succeeds.

> Key point: a failed stage blocks everything after it, so a broken build never reaches deployment.

### Experiment B: Permission error in the deploy stage

1. Open the pipeline service role in **IAM**.
2. Temporarily remove the S3 write permission for the deploy bucket (or ask the instructor to demonstrate).
3. Run the pipeline with **Release change**. The Deploy stage fails with `AccessDenied`.
4. Restore the permission and use **Retry** on the failed stage.

---

## Step 9 (optional): Add a manual approval gate

This turns the pipeline from Continuous Integration plus automatic deployment into **Continuous Delivery**.

1. Open the pipeline and choose **Edit**.
2. Between Build and Deploy, choose **Add stage**, name it `Approval`.
3. **Add action group**: action name `ManualApproval`, provider **Manual approval**.
4. Choose **Done**, then **Save**.
5. Release a change. The pipeline pauses at Approval until someone chooses **Review**, then **Approve**.

---

## Troubleshooting guide

| Symptom | Likely cause | Fix |
|---|---|---|
| Pipeline does not start on push | Connection pending or not authorized, wrong branch, trigger disabled | Check the connection status, branch name and trigger settings |
| Source stage fails | GitHub connection or repository access problem | Re-authorize the connection and confirm repository access |
| Build stage fails | Failing test or buildspec error | Open **View details**, then read the CodeBuild logs |
| Build cannot find artifact files | Wrong `base-directory` or the folder was not created | Confirm `npm run build` creates `dist/` |
| Deploy stage `AccessDenied` | Pipeline service role lacks S3 permission | Add `s3:PutObject` (and related) for the deploy bucket |
| Deploy bucket has a zip instead of files | **Extract file before deploy** not selected | Edit the Deploy action and enable it |
| Pipeline stuck waiting | Manual approval pending | Open the Approval action and approve or reject |
| Stage failed due to a temporary issue | Transient error | Use **Retry** on the failed stage |

### Useful AWS CLI commands

```bash
aws codepipeline list-pipeline-executions --pipeline-name codebuild-demo-pipeline

aws codepipeline get-pipeline-state --pipeline-name codebuild-demo-pipeline

aws codepipeline start-pipeline-execution --name codebuild-demo-pipeline
```

---

## Review questions

1. What is the difference between Continuous Delivery and Continuous Deployment?
2. What is the relationship between a stage and an action?
3. How does the build stage receive the code fetched by the source stage?
4. A commit was pushed but the pipeline did not start. List three things you would check.
5. The Build stage fails. Where do you look first to find the cause?
6. How would you add a human approval before deployment?

<details>
<summary>Suggested answers</summary>

1. Delivery keeps every change release-ready but needs a manual decision to release; Deployment releases every passing change automatically.
2. A stage is a group of actions; actions are the individual tasks within it.
3. Through artifacts: the Source action outputs `SourceArtifact`, which is the input of the CodeBuild action, passed via the S3 artifact bucket.
4. The connection status, the branch name and trigger configuration, and whether the pipeline or trigger is enabled.
5. Choose **View details** on the failed action and read the CodeBuild logs.
6. Add a stage with a **Manual approval** action before the Deploy stage.

</details>

---

## Cleanup (avoid charges)

1. Delete the pipeline `codebuild-demo-pipeline`.
2. Empty and delete the deploy bucket.
3. Empty and delete the pipeline artifact bucket (named `codepipeline-<region>-...`).
4. Delete the CodeBuild project and its CloudWatch log group.
5. Delete the GitHub connection under **Settings, Connections** in the Developer Tools console.
6. Delete the pipeline service role in IAM if no longer needed.

## Lab completion checklist

- [ ] Pipeline created with Source, Build and Deploy stages
- [ ] First execution succeeded in all stages
- [ ] Files visible in the deploy bucket
- [ ] A push to `main` started a new execution automatically
- [ ] A failing build blocked deployment and was fixed from the logs
- [ ] (Optional) Manual approval stage added

## Key takeaways

- A pipeline is stages made of actions; artifacts connect the actions.
- The source stage trigger turns every commit into an automated run.
- A failure in any stage stops the pipeline, which protects later stages.
- **View details** on a failed action is the fastest route to the real error.
- Add a manual approval to move from Continuous Deployment to Continuous Delivery.
