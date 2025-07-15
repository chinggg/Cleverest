#!/usr/bin/env python3
"""
Target Discovery Script for Cleverest Evaluation Expansion

This script automates the discovery and evaluation of potential software targets
for the Cleverest regression test generation framework.
"""

import requests
import json
import subprocess
import re
import argparse
from datetime import datetime, timedelta
from typing import List, Dict, Tuple
import time

class TargetDiscovery:
    def __init__(self, github_token: str = None):
        self.github_token = github_token
        self.headers = {
            'Accept': 'application/vnd.github.v3+json',
            'User-Agent': 'Cleverest-Target-Discovery'
        }
        if github_token:
            self.headers['Authorization'] = f'token {github_token}'
    
    def search_repositories(self, query: str, language: str = None, min_stars: int = 100) -> List[Dict]:
        """Search GitHub repositories based on criteria"""
        base_url = "https://api.github.com/search/repositories"
        
        search_query = f"{query} stars:>{min_stars}"
        if language:
            search_query += f" language:{language}"
        
        params = {
            'q': search_query,
            'sort': 'updated',
            'order': 'desc',
            'per_page': 100
        }
        
        try:
            response = requests.get(base_url, headers=self.headers, params=params)
            response.raise_for_status()
            return response.json().get('items', [])
        except requests.RequestException as e:
            print(f"Error searching repositories: {e}")
            return []
    
    def analyze_repository(self, repo: Dict) -> Dict:
        """Analyze a repository for suitability as a target"""
        repo_name = repo['full_name']
        
        # Get recent commits
        commits = self.get_recent_commits(repo_name)
        
        # Look for bug-fixing commits
        bug_commits = self.find_bug_commits(commits)
        
        # Check for CVEs and security issues
        security_issues = self.search_security_issues(repo_name)
        
        # Analyze build system
        build_info = self.analyze_build_system(repo_name)
        
        # Calculate suitability score
        score = self.calculate_score(repo, bug_commits, security_issues, build_info)
        
        return {
            'repository': repo_name,
            'description': repo.get('description', ''),
            'language': repo.get('language', ''),
            'stars': repo.get('stargazers_count', 0),
            'last_updated': repo.get('updated_at', ''),
            'bug_commits': bug_commits,
            'security_issues': security_issues,
            'build_info': build_info,
            'score': score,
            'recommendation': self.get_recommendation(score)
        }
    
    def get_recent_commits(self, repo_name: str, days: int = 365) -> List[Dict]:
        """Get recent commits for a repository"""
        url = f"https://api.github.com/repos/{repo_name}/commits"
        since_date = (datetime.now() - timedelta(days=days)).isoformat()
        
        params = {
            'since': since_date,
            'per_page': 100
        }
        
        try:
            response = requests.get(url, headers=self.headers, params=params)
            response.raise_for_status()
            return response.json()
        except requests.RequestException:
            return []
    
    def find_bug_commits(self, commits: List[Dict]) -> List[Dict]:
        """Find commits that likely fix bugs"""
        bug_keywords = [
            'fix', 'crash', 'overflow', 'vulnerability', 'cve', 'security',
            'buffer overflow', 'use after free', 'memory leak', 'segfault',
            'heap', 'stack overflow', 'null pointer', 'bounds check'
        ]
        
        bug_commits = []
        for commit in commits:
            message = commit['commit']['message'].lower()
            if any(keyword in message for keyword in bug_keywords):
                bug_commits.append({
                    'sha': commit['sha'][:7],
                    'message': commit['commit']['message'],
                    'date': commit['commit']['committer']['date'],
                    'author': commit['commit']['author']['name']
                })
        
        return bug_commits
    
    def search_security_issues(self, repo_name: str) -> List[Dict]:
        """Search for security-related issues"""
        url = f"https://api.github.com/search/issues"
        params = {
            'q': f'repo:{repo_name} CVE OR vulnerability OR security OR crash',
            'sort': 'updated',
            'order': 'desc',
            'per_page': 50
        }
        
        try:
            response = requests.get(url, headers=self.headers, params=params)
            response.raise_for_status()
            return response.json().get('items', [])
        except requests.RequestException:
            return []
    
    def analyze_build_system(self, repo_name: str) -> Dict:
        """Analyze the build system of a repository"""
        build_files = [
            'Makefile', 'CMakeLists.txt', 'configure.ac', 'configure.in',
            'meson.build', 'BUILD', 'build.gradle', 'pom.xml'
        ]
        
        build_info = {
            'build_system': 'unknown',
            'has_makefile': False,
            'has_cmake': False,
            'has_autotools': False,
            'complexity': 'unknown'
        }
        
        for build_file in build_files:
            try:
                url = f"https://api.github.com/repos/{repo_name}/contents/{build_file}"
                response = requests.get(url, headers=self.headers)
                if response.status_code == 200:
                    if build_file == 'Makefile':
                        build_info['has_makefile'] = True
                        build_info['build_system'] = 'make'
                    elif build_file == 'CMakeLists.txt':
                        build_info['has_cmake'] = True
                        build_info['build_system'] = 'cmake'
                    elif build_file in ['configure.ac', 'configure.in']:
                        build_info['has_autotools'] = True
                        build_info['build_system'] = 'autotools'
            except requests.RequestException:
                continue
        
        return build_info
    
    def calculate_score(self, repo: Dict, bug_commits: List[Dict], 
                       security_issues: List[Dict], build_info: Dict) -> int:
        """Calculate suitability score for a repository"""
        score = 0
        
        # Language preference (C/C++ get higher scores)
        language = repo.get('language', '').lower()
        if language in ['c', 'c++']:
            score += 3
        elif language in ['rust', 'go']:
            score += 2
        elif language in ['python', 'javascript', 'java']:
            score += 1
        
        # Activity level (recent updates)
        last_updated = datetime.fromisoformat(repo['updated_at'].replace('Z', '+00:00'))
        days_since_update = (datetime.now().replace(tzinfo=last_updated.tzinfo) - last_updated).days
        if days_since_update < 30:
            score += 3
        elif days_since_update < 90:
            score += 2
        elif days_since_update < 365:
            score += 1
        
        # Bug history (more security bugs = higher score)
        bug_score = min(len(bug_commits), 5)  # Cap at 5 points
        score += bug_score
        
        security_score = min(len(security_issues), 3)  # Cap at 3 points
        score += security_score
        
        # Build system compatibility
        if build_info['build_system'] in ['make', 'cmake', 'autotools']:
            score += 2
        elif build_info['build_system'] != 'unknown':
            score += 1
        
        # Repository popularity (more stars = more stable)
        stars = repo.get('stargazers_count', 0)
        if stars > 10000:
            score += 3
        elif stars > 1000:
            score += 2
        elif stars > 100:
            score += 1
        
        return score
    
    def get_recommendation(self, score: int) -> str:
        """Get recommendation based on score"""
        if score >= 12:
            return "HIGH - Excellent candidate for integration"
        elif score >= 8:
            return "MEDIUM - Good candidate, needs investigation"
        elif score >= 5:
            return "LOW - Possible candidate with limitations"
        else:
            return "SKIP - Not suitable for current evaluation"
    
    def generate_report(self, targets: List[Dict], output_file: str = None):
        """Generate a comprehensive report of analyzed targets"""
        # Sort by score (highest first)
        targets.sort(key=lambda x: x['score'], reverse=True)
        
        report = []
        report.append("# Cleverest Target Discovery Report")
        report.append(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        report.append("")
        
        # Summary statistics
        high_priority = [t for t in targets if t['score'] >= 12]
        medium_priority = [t for t in targets if 8 <= t['score'] < 12]
        
        report.append("## Summary")
        report.append(f"- Total repositories analyzed: {len(targets)}")
        report.append(f"- High priority candidates: {len(high_priority)}")
        report.append(f"- Medium priority candidates: {len(medium_priority)}")
        report.append("")
        
        # High priority targets
        if high_priority:
            report.append("## High Priority Targets")
            for target in high_priority:
                report.append(f"### {target['repository']} (Score: {target['score']})")
                report.append(f"**Description**: {target['description']}")
                report.append(f"**Language**: {target['language']}")
                report.append(f"**Stars**: {target['stars']}")
                report.append(f"**Bug Commits**: {len(target['bug_commits'])}")
                report.append(f"**Security Issues**: {len(target['security_issues'])}")
                report.append(f"**Build System**: {target['build_info']['build_system']}")
                report.append("")
        
        # Medium priority targets
        if medium_priority:
            report.append("## Medium Priority Targets")
            for target in medium_priority:
                report.append(f"### {target['repository']} (Score: {target['score']})")
                report.append(f"**Description**: {target['description']}")
                report.append(f"**Language**: {target['language']}")
                report.append("")
        
        report_text = "\n".join(report)
        
        if output_file:
            with open(output_file, 'w') as f:
                f.write(report_text)
            print(f"Report saved to {output_file}")
        else:
            print(report_text)

def main():
    parser = argparse.ArgumentParser(description='Discover potential targets for Cleverest evaluation')
    parser.add_argument('--token', help='GitHub API token for higher rate limits')
    parser.add_argument('--output', help='Output file for the report')
    parser.add_argument('--query', default='parser compiler interpreter', help='Search query')
    parser.add_argument('--language', help='Programming language filter')
    parser.add_argument('--min-stars', type=int, default=100, help='Minimum star count')
    
    args = parser.parse_args()
    
    discovery = TargetDiscovery(args.token)
    
    print("Searching for repositories...")
    repos = discovery.search_repositories(args.query, args.language, args.min_stars)
    print(f"Found {len(repos)} repositories")
    
    targets = []
    for i, repo in enumerate(repos[:20]):  # Limit to first 20 for API rate limits
        print(f"Analyzing {repo['full_name']} ({i+1}/{min(20, len(repos))})")
        target = discovery.analyze_repository(repo)
        targets.append(target)
        time.sleep(1)  # Rate limiting
    
    print("\nGenerating report...")
    discovery.generate_report(targets, args.output)

if __name__ == "__main__":
    main()