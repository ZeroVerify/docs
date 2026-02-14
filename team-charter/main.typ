#set page(
  paper: "us-letter",
  margin: (x: 0.75in, y: 0.75in),
)
#show link: underline
#set heading(numbering: "1.")
#set text(size: 10pt)

#align(center)[
  #text(size: 18pt, weight: "bold")[
    ZeroVerify Team Charter
  ]
  #v(0.3em)
  #text(size: 11pt, style: "italic")[
    Standard Operating Procedures for ZeroVerify team
  ]
  #v(0.3em)
  #text(size: 9pt)[
    Version 1.1 | Last Updated: February 2025
  ]
]

= Team Members

- Lisa Nguyen
- Anton Sakhanovych
- Souleymane Sono
- Fateha Ima
- Simon Griemert

= Communication Protocol

== Channels
- *Discord:* All project decisions, technical discussions, sprint coordination, and blocker notifications
- *GitHub:* Code reviews, issues, pull requests, and technical documentation
- *Email:* Professor escalations only

== Response Time Commitments
- *Discord direct mentions:* Acknowledge within 24 hours (weekdays), 48 hours (weekends)
- *Code review requests:* Initial review within 24 hours
- *Blocker notifications:* Response required within 12 hours
- *Pull request approvals:* Complete review within 48 hours of request

== Communication Standards
- *The Golden Rule:* We critique code, not people. Technical disagreements focus on tradeoffs and project goals, not individual competence.
- No critical project decisions via private DMs, all decisions happen in shared Discord channels.
- Use thread replies in Discord to keep discussions organized.
- Tag specific people when requesting action or input.

= Meeting Schedule

All meeting times are arranged and agreed upon in the Discord group channel to accommodate team members' schedules.

== Sprint Structure (2-week iterations)

*Sprint Planning* 
- Review completed work from previous sprint
- Select user stories for upcoming sprint
- Break stories into tasks and assign ownership

*Daily Standups* 
- What did I complete yesterday?
- What am I working on today?
- Am I blocked? If yes, what specifically blocks me? How can team help to unblock you?

*Backlog Refinement* 
- Clarify upcoming user stories
- Estimate story points
- Demo completed features (working code only)
- Assign RAG status to project
- Retrospective: What went well? What needs improvement?
- Action items for next sprint

= Definition of Done

A task is *DONE* when all criteria are met:

1. Code pushed to feature branch with descriptive commit messages following conventional commits format
2. Pull request opened with:
   - Clear description of changes
   - Link to related issue/user story
   - Screenshots/test results if applicable
3. At least one other team member has reviewed and approved the PR
4. All tests pass (unit tests minimum, integration tests where applicable)
5. Documentation updated:
   - README if setup changed
   - API documentation if endpoints modified
6. Code merged to `main` branch

== Code Quality Standards
- *Branch naming:* `feature/short-description`, `bugfix/issue-number`, `docs/what-changed`

= Blocker Management

== Recognizing Blockers

You are *blocked* if:
- Cannot make progress for more than 4 hours
- Need information, access, credentials, or decisions from another team member
- Uncertain about technical approach and need architectural guidance
- External dependencies (university OAuth, APIs) are unavailable
- Conflicting requirements between capstone and thesis

== Resolution Process

=== Phase 1: Self-Help (0-4 hours)
1. Document the problem clearly (what you're trying to do, what's failing)
2. Search existing resources (project docs, GitHub issues, relevant documentation)
3. Attempt at least two different approaches
4. Timebox your struggle at 4 hours maximum

=== Phase 2: Team Assistance (4-24 hours)
1. Post in Discord channel with:
   - Clear description of the blocker
   - What you've already tried (show your work)
   - Specific questions or help needed
   - Tag relevant team members
   - Urgency level: `[CAN CONTINUE OTHER WORK]` or `[COMPLETELY BLOCKED]`

2. For complex technical blockers:
   - Request 15-30 minute pair programming session
   - Scrum Master facilitates scheduling within 24 hours

3. Decision timeout:
   - If no technical consensus within 24 hours, trigger Technical Tie-Breaker

=== Phase 3: Technical Tie-Breaker (for deadlocked decisions)
When team cannot agree on technical approach after 24 hours:

1. Each side prepares written proposal (max 1 page) covering:
   - Alignment with project goals (security, privacy, usability, scalability)
   - Implementation complexity and timeline impact

2. Team reviews proposals and votes

3. If no majority reached, current Scrum Master makes final decision based on:
   - Available expertise on team
   - Time remaining in sprint/semester

= Conflict Resolution Framework

== Conflict Types & Resolution Paths

=== Technical Conflict
*Symptoms:* Extended debate over architecture, technology choices, API design, database schema

*Resolution (48 hours):*
- Follow Technical Tie-Breaker protocol (Section 5.3)
- If still unresolved, schedule 30-minute meeting with all team members. 

=== Commitment Conflict
*Symptoms:* Missed deadlines, incomplete tasks, unresponsiveness, "ghosting"

*Resolution (48 hours):*
1. Scrum Master(or the person blocked) initiates private one-on-one conversation
2. Use "I" statements focusing on impact:
   - *Wrong:* "You never finish your code on time"
   - *Right:* "I'm blocked on frontend work because the API endpoints aren't ready. Can we discuss what's preventing progress?"
3. Identify root cause:
   - Overload from other classes #sym.arrow redistribute tasks
   - Technical difficulty #sym.arrow schedule pair programming
   - Unclear requirements #sym.arrow clarify and document
   - Personal issues #sym.arrow adjust sprint commitments realistically

*3-Day Rule:* If team member is unresponsive for 3 consecutive days without prior notice, trigger professor escalation.

=== Structural Conflict
*Symptoms:* Task overlap, unclear ownership, duplicated work, integration failures

*Resolution (Immediate Meeting within 24 hours):*
1. Stop current work and schedule 30-minute meeting
2. Review and update:
   - GitHub project board assignments
   - Definition of Done for each role
   - API contracts and integration points
3. Document decisions in the docs repository
4. Redistribute work to eliminate overlap

=== Interpersonal Conflict
*Symptoms:* Passive-aggressive comments, tension in meetings, communication breakdown
  
*Resolution (48-hours):*
1. Address directly but privately within 48 hours (don't let it fester)
2. Use non-judgmental language focused on behavior impact:
   - *Wrong:* "You're always dismissive in code reviews"
   - *Right:* "When my PRs receive comments like 'this won't work' without explanation, I feel my approach isn't being considered. Can we discuss the technical tradeoffs more thoroughly?"
3. If unresolved after private conversation, Scrum Master mediates
4. If mediation fails, trigger professor escalation
5. For harassment or ethics violations, escalate immediately (no 48-hour wait)

= Professor Escalation Protocol

== When to Escalate (Point of No Return)

*Immediate Escalation (within 24 hours):*
- Harassment, discrimination, or bullying

*Escalation Within 48 Hours:*
- *Ghosting:* Team member unresponsive for 3+ consecutive days without prior communication
- *Deadlock:* Technical or process disagreement has completely halted project progress for 1+ week

*Escalation Format:*

Email to professor with subject: `[CAPSTONE ESCALATION] Brief Description`

Body should include:
1. *Context:* What conflict occurred and when it started
2. *Resolution Attempts:* What we tried internally (reference specific charter sections)
3. *Current Impact:* How this affects project timeline, deliverables, and team function
4. *Request:* Specific help needed (mediation, deadline adjustment, requirement clarification)

= Sprint Tracking & Health Monitoring

== RAG Status Assessment

At end of every backlog refinement, team assigns project health status:

*Green:* On track
- All sprint commitments met or >80% complete
- No critical blockers
- Team morale positive

*Amber:* At risk (action plan required)
- 1-2 milestones behind schedule
- Significant technical hurdle discovered
- Team member struggling but responsive

*Red:* Critical (escalation required)
- Significantly behind schedule (>2 weeks slip)
- Core feature failing/not feasible
- Team conflict unresolved after 48 hours

Action: If Red status persists for 2 consecutive sprints, automatic professor escalation.

== GitHub Project Board Structure

*Columns:*
1. *Backlog* (prioritized, not yet refined)
2. *Ready* (refined with acceptance criteria, can be started)
3. *In Progress* (assigned, actively being worked)
4. *In Review* (PR open, awaiting approval)
5. *Done* (merged to main, documented)

*Required Labels:*
- Priority: `priority: critical`, `priority: high`, `priority: low`
- Type: `type: feature`, `type: bug`, `type: docs`, `type: infrastructure`
- Status: `blocked` (with comment explaining blocker)

*Board Maintenance:*
- Scrum Master updates at least twice per week
- All team members responsible for moving their own cards
- `blocked` label triggers immediate Scrum Master attention

= Decision-Making Framework (GIST)

For proposing new features, technical approaches, or scope changes:

*Goal:* What problem are we solving? How does this align with zero-knowledge student verification and project success criteria?

*Ideas:* What are 2-3 alternative approaches? What are the tradeoffs?

*Step-Project:* What's the smallest version we can build to validate this idea? Can we prototype in one sprint?

*Tasks:* Break down into implementable units (\<8 hours each) with clear acceptance criteria.

= Post-Conflict Protocol

After any conflict resolution:

1. *Update Processes:* If conflict revealed gap in this charter, propose amendment via PR
2. *Reset RAG Status:* Move from Red #sym.arrow Amber or Amber #sym.arrow Green with documented recovery plan
3. *Blameless Retrospective:* In next sprint retro, discuss what we learned as a system failure, not individual failure
4. *Move Forward:* Once resolved, discussion is closed-focus returns entirely to code and deliverables

*Forgiveness Clause:* Capstone is high-pressure and runs concurrently with other demanding coursework. We acknowledge stress happens, extract lessons from conflicts, and do not hold grudges. Every sprint is a fresh start.

= Charter Amendments

*Process:*
1. Any team member can propose amendment via PR
2. Discuss in next scheduled team meeting
3. Requires 4 out of 5 votes to adopt
4. Version number increments, change log updated

#v(2em)
#align(center)[
  #text(size: 9pt, style: "italic")[
    Winter is coming. So is the deadline. Critique code, not teammates.
    \
    The North remembers. So does your Git history. Be kind.
  ]
]

#pagebreak()

#heading(numbering: none)[Signatures]

By signing below, all team members acknowledge they have read, understood, and agree to abide by the terms outlined in this Team Charter.

#v(2em)

#grid(
  columns: (1fr, 1fr),
  row-gutter: 3em,
  column-gutter: 2em,

  [
    #line(length: 100%, stroke: 0.5pt)
    Lisa Nguyen
    #v(0.5em)
    Date: #h(1fr)
  ],

  [
    #line(length: 100%, stroke: 0.5pt)
    Anton Sakhanovych
    #v(0.5em)
    Date: #h(1fr)
  ],

  [
    #line(length: 100%, stroke: 0.5pt)
    Souleymane Sono
    #v(0.5em)
    Date: #h(1fr)
  ],

  [
    #line(length: 100%, stroke: 0.5pt)
    Fateha Ima
    #v(0.5em)
    Date: #h(1fr)
  ],

  [
    #line(length: 100%, stroke: 0.5pt)
    Simon Griemert
    #v(0.5em)
    Date: #h(1fr)
  ],
)
