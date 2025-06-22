<!-- skip:true -->
# 🔍 Local Operation Verification Checklist

This file defines the checklist items to be performed during local operation verification after Pull Request creation.
When the Issue Manager executes the local_verification function, verification is performed based on the contents of this file.

## Basic Check Items

<Creating a checklist in markdown enables local verification to be executed>

## Environment Setup Procedures

### 1. Development Environment Preparation
```bash
# Move to branch (automatically executed by Issue Manager)
mkdir -p worktree
git worktree add worktree/issue-{issue_number} -b issue-{issue_number}
cd worktree/issue-{issue_number}

# Install dependencies
npm install
# or yarn install
# or pip install -r requirements.txt
```

### 2. Server Startup
```bash
# Start development server
npm run dev
# or npm start
# or yarn dev
# or python manage.py runserver
# or python app.py

# For background startup
npm run dev &
SERVER_PID=$!
```

### 3. Access Method
```bash
# Open browser (macOS)
open http://localhost:3000

# Open browser (Linux)
xdg-open http://localhost:3000

# Manually open browser
# http://localhost:3000
# http://localhost:8000
# http://localhost:5000
```

### 4. Cleanup After Verification
```bash
# Stop server
kill $SERVER_PID
# or Ctrl+C

# Clean up test data (if necessary)
npm run db:reset
```

## Verification Procedure Notes

### Verification Environment
- Browsers: Chrome, Firefox, Safari
- Devices: PC, Tablet, Smartphone
- OS: macOS, Windows, Linux

### URLs/Pages to Verify
- Top page: http://localhost:3000/
- [Please add other pages here]

### Test Data
- Test users: [Test account information]
- Test data: [Required datasets]

## Notes

### Local Verification Execution Conditions
- ✅ This file exists
- ✅ First line is not `<!-- skip:true -->`

### How to Skip Local Verification
```markdown
<!-- skip:true -->
```
Adding the above comment to the first line of the file will skip local verification.

### Other Notes
- Please customize check items according to project characteristics
- When adding new features, please add related check items
- Use `<!-- skip:true -->` to temporarily disable local verification
- Delete the file to completely disable it

---

**Usage**:
1. Customize check items according to project
2. Issue Manager automatically performs local verification after PR creation
3. Record verification results as comments on GitHub Issue
