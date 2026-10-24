# codebuild-demo

Small Node.js sample application used in the **AWS CodeBuild** hands-on lab
(DevOps on AWS – Intermediate).

## Project layout

| File | Purpose |
|---|---|
| `app.js` | Application code (`add`, `greet` and a tiny HTTP server) |
| `app.test.js` | Unit tests (Node built-in test runner, no dependencies) |
| `package.json` | Scripts: `start`, `test`, `build` |
| `package-lock.json` | Lock file used by `npm ci` in the build |
| `buildspec.yml` | CodeBuild build instructions |
| `.gitignore` | Keeps `node_modules/` and `dist/` out of Git |

## Run locally (Node.js 18 or later)

```bash
npm ci          # install dependencies (none required, uses the lock file)
npm test        # run unit tests
npm run build   # create dist/ with the deployable files
npm start       # start the server on http://localhost:3000
```

## Push to GitHub

```bash
git init
git add .
git commit -m "Initial commit: sample app with buildspec"
git branch -M main
git remote add origin https://github.com/<your-username>/codebuild-demo.git
git push -u origin main
```

## Build with AWS CodeBuild

1. Create a CodeBuild project with this GitHub repository as the source.
2. Use a managed Amazon Linux image and choose **Use a buildspec file**.
3. Set artifacts to an S3 bucket (zip) and keep CloudWatch Logs enabled.
4. Start the build. It runs `npm ci`, `npm test` and `npm run build`, then uploads `dist/` as the artifact.

## Break and fix (practice)

- Change the expected value in `app.test.js` (for example `5` to `6`), push, and watch the BUILD phase fail.
- Change `npm run build` to `npm run biuld` in `buildspec.yml` and read the error in the logs.
