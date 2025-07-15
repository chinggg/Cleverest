# Research Methodology for Expanding Cleverest Target Portfolio

## Overview

This document provides a systematic methodology for identifying, evaluating, and integrating new software targets into the Cleverest regression test generation framework. The goal is to expand the experimental scope while maintaining rigorous evaluation standards.

## Target Identification Criteria

### Primary Requirements

1. **Text-Based Input Format**
   - Must accept textual input that LLMs can generate naturally
   - Examples: Source code, markup languages, configuration files, structured data formats
   - Avoid binary-only formats (images, executables, compressed files)

2. **Active Development**
   - Recent commits within last 6 months
   - Active issue tracker with regular bug reports
   - Established development community

3. **Historical Bug Data**
   - Documented bugs with clear commit hashes for introduction and fixes
   - Preferably with CVE numbers or detailed security advisories
   - PoC exploits or test cases that reproduce the bugs

4. **Command-Line Interface**
   - Can be invoked from command line with file input
   - Deterministic behavior suitable for automated testing
   - Clear success/failure indicators

### Secondary Preferences

1. **Build System Compatibility**
   - Works with common build systems (Make, CMake, autotools)
   - Can be built with AddressSanitizer and coverage instrumentation
   - Reasonable build time (< 30 minutes)

2. **Programming Language Diversity**
   - Prefer C/C++ for memory safety bug detection
   - Consider Rust/Go for different bug classes
   - Avoid interpreted languages without native components

3. **Domain Coverage**
   - Fill gaps in current evaluation (parsers, compilers, databases, etc.)
   - Represent different software categories
   - Include both systems and application software

## Systematic Target Discovery Process

### Phase 1: Automated Repository Mining

Use GitHub API to identify candidates:

```bash
# Search for repositories by programming language and activity
gh search repos --language=c --sort=updated --order=desc --limit=100 "parser OR compiler OR interpreter"
gh search repos --language=cpp --sort=updated --order=desc --limit=100 "json OR xml OR yaml"

# Filter by recent security issues
gh search issues --sort=updated "CVE" "buffer overflow OR use after free OR heap overflow"
```

### Phase 2: Manual Curation

For each candidate repository:

1. **Evaluate Input Format**
   - Review documentation for supported input formats
   - Test with simple inputs to verify text-based processing
   - Assess complexity of input format (structured vs. free-form)

2. **Analyze Bug History**
   - Review last 2 years of security advisories
   - Identify commits that fix parsing/processing bugs
   - Look for fuzzing or security research mentions

3. **Assess Build Complexity**
   - Clone and attempt basic build
   - Test with sanitizers enabled
   - Evaluate dependency requirements

### Phase 3: Validation and Ranking

Score each candidate (1-5 scale) on:

- **Input Suitability** (5 = pure text, 1 = mostly binary)
- **Bug Frequency** (5 = frequent security bugs, 1 = rare bugs)
- **Development Activity** (5 = daily commits, 1 = monthly releases)
- **Integration Effort** (5 = trivial, 1 = significant work)

Total possible score: 20 points
Minimum threshold for consideration: 12 points

## Bug Mining and Commit Identification

### Automated Bug Discovery

```python
# Example script for mining bug-fix commits
import requests
import re

def find_bug_fixing_commits(repo_url, keywords):
    """Find commits that likely fix bugs based on commit messages"""
    api_url = repo_url.replace('github.com', 'api.github.com/repos')
    commits = requests.get(f"{api_url}/commits").json()
    
    bug_keywords = ['fix', 'crash', 'overflow', 'vulnerability', 'CVE']
    bug_commits = []
    
    for commit in commits:
        message = commit['commit']['message'].lower()
        if any(keyword in message for keyword in bug_keywords):
            bug_commits.append({
                'sha': commit['sha'][:7],
                'message': commit['commit']['message'],
                'date': commit['commit']['committer']['date']
            })
    
    return bug_commits
```

### Manual Bug Analysis

For each identified bug-fixing commit:

1. **Find Bug-Introducing Commit**
   ```bash
   git log --reverse --ancestry-path <bug_fix_commit>^..<bug_fix_commit>
   git bisect start <bug_fix_commit> <last_known_good>
   ```

2. **Create Test Case**
   - Use git diff to understand the fix
   - Create minimal input that triggers the bug in unfixed version
   - Verify the test case works with both versions

3. **Document the Bug**
   - CVE number (if applicable)
   - Bug class (buffer overflow, use-after-free, etc.)
   - Affected components
   - PoC test case

## Target Integration Process

### Step 1: Environment Configuration

Create `<target>.env` file following the established pattern:

```bash
#!/bin/bash

PROJ_NAME=<name>
PROJ_DESC="<description>"
PROJ_REPO=<git_url>
EXE=<binary_name>
DIR_REL=<relative_path_to_binary>

ISSUES=(
  <issue_numbers>
)

COMMITS_BIC=(
  <bug_introducing_commits>
)

COMMITS_FIX=(
  <bug_fixing_commits>
)

# ... standard functions ...
```

### Step 2: Build System Integration

Implement required functions:
- `clone_repo()` - Repository setup
- `build_target()` - Standard build with sanitizers
- `buildafl_target()` - AFL-compatible build
- `gen_cov()` / `check_cov()` - Coverage analysis

Test build process:
```bash
export conf=<target>.env
SCENARIO=BIC ./b.sh $conf
SCENARIO=FIX ./b.sh $conf
```

### Step 3: Command Integration

Define command patterns for the target:
```bash
COMMANDS=(
    "<exe> <args> @@"
    "<exe> <different_args> @@"
)
```

Test basic functionality:
```bash
MAX_ITER=1 ./run.sh $conf
```

### Step 4: Validation

1. **Verify Bug Reproduction**
   - Test that BIC version crashes on PoC inputs
   - Test that FIX version handles inputs safely
   - Validate with AddressSanitizer output

2. **Test LLM Integration**
   - Run with single iteration to verify LLM can generate inputs
   - Check that generated inputs exercise target functionality
   - Verify feedback loop works correctly

3. **Performance Assessment**
   - Measure build time and resource requirements
   - Test execution time with various input sizes
   - Ensure reasonable performance for batch evaluation

## Quality Assurance Checklist

### Before Integration

- [ ] Target accepts text-based input format
- [ ] Recent development activity (< 6 months)
- [ ] Documented security bugs with commit hashes
- [ ] Successful build with sanitizers
- [ ] Command-line interface available
- [ ] PoC test cases work as expected

### After Integration

- [ ] Environment file follows standard format
- [ ] All build functions implemented and tested
- [ ] Bug reproduction verified for all commits
- [ ] LLM integration works correctly
- [ ] Coverage analysis functions properly
- [ ] Performance meets requirements
- [ ] Documentation updated

## Risk Assessment and Mitigation

### Common Integration Challenges

1. **Complex Build Dependencies**
   - Mitigation: Use containerized build environments
   - Document all required packages and versions

2. **Binary Input Formats**
   - Mitigation: Look for text-based configuration or command options
   - Consider hybrid approaches with text metadata

3. **Inconsistent Bug Data**
   - Mitigation: Manual verification of all commit pairs
   - Cross-reference with CVE databases and security advisories

4. **Performance Issues**
   - Mitigation: Profile and optimize build/test processes
   - Set reasonable timeout limits

### Validation Strategies

1. **Cross-Reference Validation**
   - Compare findings with existing fuzzing results
   - Validate against known CVE databases
   - Cross-check with security research papers

2. **Independent Reproduction**
   - Have multiple team members verify bug reproduction
   - Test on different systems and compiler versions
   - Document exact reproduction steps

3. **Baseline Comparison**
   - Compare new targets against existing ones
   - Ensure similar complexity and scope
   - Validate that improvements are meaningful

## Documentation and Reporting

### For Each New Target

1. **Integration Report**
   - Target description and justification
   - Bug summary with CVE numbers
   - Build and integration notes
   - Performance metrics

2. **Evaluation Results**
   - Success rates by scenario and configuration
   - Bug detection effectiveness
   - Coverage analysis results
   - Comparison with existing targets

3. **Lessons Learned**
   - Integration challenges and solutions
   - Recommendations for similar targets
   - Potential improvements to the framework

This methodology ensures systematic expansion of the evaluation scope while maintaining research rigor and reproducibility.