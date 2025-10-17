# Contributing to scripts

Thank you very much for taking your time to contribute to gt :smiley:

Following a few guidelines so that others can quickly benefit from your contribution.

*Table of Content*: [Code of Conduct](#code-of-conduct), [How to Contribute](#how-to-contribute), 
[Your First Code Contribution](#your-first-code-contribution), [Coding Conventions](#coding-conventions),
[Pull Request Checklist](#pull-request-checklist).

## Code of Conduct
This project and everyone participating in it is governed by this project's 
[Code of Conduct](https://github.com/tegonal/gt/tree/main/.github/CODE_OF_CONDUCT.md). 
By participating, you are expected to uphold this code. Please report unacceptable behaviour to info@tutteli.ch

## How to Contribute
- Star scripts if you like it.

- Need help using one of the scripts?  
  Open a [new discussion](https://github.com/tegonal/gt/discussions/new?category=q-a) 
  and write down your question there and we will get back to you.
  
- Found a bug?  
  [Open an issue](https://github.com/tegonal/gt/issues/new?template=bug_report.md).
  
- Missing a feature?  
  Open a [new discussion](https://github.com/tegonal/gt/discussions/new?category=ideas)
  and write down your need and we will get back to you.
  
- You do not have a particular feature in mind but would like to contribute with code?
  Please have a look at the [help wanted issues](https://github.com/tegonal/gt/issues?q=is%3Aissue+is%3Aopen+label%3A%22help+wanted%22)
  Open a [new discussion](https://github.com/tegonal/gt/discussions/new?category=contributor-q-a) if there are not any.  
  There are certainly ways you can still help us with coding.  

- Found spelling mistakes?  
  Nice catch :mag: Please fix it and create a pull request.
  
- You have other ideas how a certain script could be improved?   
  Open a [new discussion](https://github.com/tegonal/gt/discussions/new?category=ideas)
  and write down your idea, we are looking forward to it.

In any case, if you are uncertain how you can contribute, then contact us via a 
[new discussion](https://github.com/tegonal/gt/discussions/new?category=contributor-q-a)
and we will figure it out together :smile:

## Your First Code Contribution
Fantastic, thanks for your effort! 
 
The following are a few guidelines on how we suggest you start.
 
1. Fork the repository to your repositories (see [Fork a repo](https://help.github.com/en/articles/fork-a-repo) for help). 
2. Use an IDE which supports bash coding and shellcheck (min. v0.11.0)
   e.g. [visual studio code](https://code.visualstudio.com) with the [shellcheck](https://marketplace.visualstudio.com/items?itemName=timonwong.shellcheck) plugin,
   or [Intellij's IDEA](https://www.jetbrains.com/idea/download) which has a bundled shellcheck plugin.
   Add the following arguments to shellcheck to stay par with scripts/run-shellcheck.sh:  
   `--check-sourced --color=always --external-sources --enable=all --source-path="./lib/tegonal-scripts/src:./scripts"`
   (e.g. by creating a shellcheck_custom.sh in ~/.local/bin which points to your shellcheck and passes the above parameters and `$@` additionally.)
   Without passing the arguments you might see warnings such as unassigned variables due to the missing source paths.

3. Read up the [Coding Conventions](#coding-conventions) (there are only 5 points).

Perfect, you are setup and ready to go. 
Have a look at [help wanted issues](https://github.com/tegonal/gt/issues?q=is%3Aissue+is%3Aopen+label%3A%22help+wanted%22)
where [good first issues](https://github.com/tegonal/gt/issues?q=is%3Aissue+is%3Aopen+label%3A%22good+first+issue%22)
are easier to start with.
Please write a comment such as `I'll work on this` in the issue,
this way we can assign the task to you (so that others know there is already someone working on the issue)
and it gives us the chance to have a look at the description again and revise if necessary.

<a name="git"></a>
*Git*  

Dealing with Git for the first time? Here are some recommendations for how to set up Git when working on an issue: 
- create a new branch for the issue using `git checkout -b <branch-name>` (preferably, the branch name
  should be descriptive of the issue or the change being made, e.g `#108-path-exists`.) Working
  on a new branch makes it easier to make more than one pull request.
- add this repository as a remote repository using
 `git remote add upstream https://github.com/tegonal/gt.git`. You will use this to
  fetch changes made in this repository.
- to ensure your branch is up-to-date, rebase your work on
  upstream/main using `git rebase upstream/main` or `git pull -r upstream main`.
  This will add all new changes in this repository into your branch and place your
  local unpushed changes at the top of the branch.

You can read more on Git [here](https://git-scm.com/book/).

Contact us via a [new discussion](https://github.com/tegonal/gt/discussions/new?category=contributor-q-a)
whenever you need help to get up and running or have questions.

We recommend you create a pull request (see [About pull requests](https://help.github.com/en/articles/about-pull-requests) for help)
in case you are not sure how you should do something. 
This way we can give you fast feedback regarding multiple things (style, does it go in the right direction etc.) before you spend time for nothing.
Prepend the title with `[WIP]` (work in progress) or mark it as draft in this case and leave a comment with your questions.

Finally, when you think your PR (short for pull request) is ready, then please:

1. read the [Pull Request Checklist](#pull-request-checklist) 
2. Create your first pull-request
3. 👏👏👏 you have submitted your first code contribution to workflow-helper :blush:

## Coding Conventions
So far we do not try to enforce too much. We will review your pull requests and comment if necessary.
However, here a few hints in order that your pull request is merged quickly.
1. Make sure shellcheck does not generate warnings.
2. Try to write code in a similar style as the existing 
   (We suggest you copy something existing and modify it).
3. Write readable code and express comments with code rather than comments.
4. Provide documentation for scripts (see existing scripts).
5. Write your commit message in an [imperative style](https://chris.beams.io/posts/git-commit/).     

## Pull Request Checklist
Please make sure you can check every item on the following list before you create a pull request:  
- [ ] your pull request is rebased on the [latest commit on main](https://github.com/tegonal/gt/commits/main)
- [ ] Your pull request addresses only “one thing”. It cannot be meaningfully split up into multiple pull requests.
- [ ] There is no error if you run ./scripts/before-pr.sh
- [ ] Make sure you have no changes after running ./scripts/before-pr.sh and `git commit --amend` otherwise
     
Once you have created and submitted your pull request, make sure:
- [ ] your pull request passes Continuous Integration
