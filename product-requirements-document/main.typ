#set page(
  paper: "us-letter",
  margin: (x: 1in, y: 1in),
)

#set par(justify: true)
#show link: underline

#align(center)[
  #text(size: 16pt, weight: "bold")[
    Product Requirement Document (PRD)
  ]

  #v(0.3em)

  #text(size: 11pt)[
    Date: 2/22/26 | Team: Lisa Nguyen (CS), Anton Sakhanovyvh (CS), Souleymane Sono (CS), Fateha Ima (CS), Simon Griemert (CS)
  ]

  #v(1.5em)
]

= Executive Summary

== The Hook

Over 17 billion personal records were compromised in 2023 alone (Flashpoint 2024 Global Threat Intelligence Report). The dominant identity verification protocols in use today, SAML, OAuth, OpenID Connect, are designed to transmit full identity attribute sets rather than selective proofs of individual claims. An organization verifying student status receives a name, institutional affiliation, date of birth, and email address because that is what the protocol delivers. There is no native mechanism for a verifier to request only what a transaction requires and receive only that. When systems built on these protocols are breached, the exposed records reflect everything the protocol required them to collect. ZeroVerify attacks the collection requirement itself.

== The Problem

Current digital identity verification operates on a structural mismatch between what verifiers need and what protocols deliver. To confirm a single boolean claim ("Is this a person a student?"), SAML, OAuth, OIDC return a full attribute assertion containing every identity field the institution has on record. Once the transmission occurs, the user has no mechanism to limit how the data is used, how long it is retained, or whether it is deleted at all. No existing system integrates zero-knowledge proofs into standard OAuth 2.0 and OIDC flows such that a verifier can confirm a claim about a user's identity without receiving any personal attributes at all, and without requiring organizations to replace their existing identity infrastructure.

== The Solution

ZeroVerify is a privacy-preserving identity verification layer that integrates with the identity infrastructure universities and enterprises already operate. It addresses the structural problem of attribute over-disclosure not by minimizing what is shared, but by eliminating attribute disclosure entirely from the verification event.

The system works in two phases. In the issuance phase, ZeroVerify federates with an institution's existing IdP via Keycloak acting as an identity broker. The institution requires no modification; from its perspective, Keycloak is a standard service provider. ZeroVerify's issuance layer extracts the verified attributes from the claims set and produces a BBS+ signed verifiable credential, which is delivered to and stored in the user's mobile wallet. The raw credential never leaves the device after this point.

In the verification phase, a verifier issues a challenge requesting confirmation of a specific boolean claim, for example "Is this person over 21?" or "Is this person an active student?" The user's wallet uses the stored credential as a private witness to a zk-SNARK circuit specific to that claim type. The circuit produces a cryptographic proof that the claim is true without encoding any attribute value in the proof output. The verifier submits this proof to ZeroVerify's library, which checks cryptographic correctness, confirms the challenge nonce has not been previously consumed (preventing replay attacks), and checks the credential's revocation status against a W3C Status List bitstring. The verifier receives a single result: valid or invalid. No name, no birthdate, no institutional affiliation, no personal data of any kind is transmitted to the verifier at any point in this flow.

The integration boundary is deliberately placed so that neither the institution nor the verifier needs to understand or adopt zero-knowledge proof systems. The institution speaks SAML, OAuth, OIDC. The verifier calls two SDK functions. ZeroVerify handles the cryptographic complexity in between.

== Technical Approach

ZeroVerify is built on four core technologies: BBS+ signatures for credential issuance, Groth-16 zk-SNARKs compiled in circom for circuit definition, Keycloak as a SAML/OAuth-to-OIDC broker, and snarkjs for client-side proof generation. The backend runs on AWS Lambda and DynamoDB Global Tables across three regions, with W3C Status List revocation state stored in S3.

The technical challenge is composing zk-SNARKs and BBS+ signatures into a system that speaks the protocols universities and enterprises already operate, SAML, OAuth, OIDC, without requiring those institutions to change anything on their end. Keycloak bridges that gap as SAML/OAuth-to-OIDC broker, normalizing heterogeneous institutional identity systems into a consistent claims surface that ZeroVerify's issuance layer can sign into verifiable credentials. The second hard problem is that proof generation must run entirely on the user's mobile device, because sending the raw credential to a server for proof generation would defeat the privacy guarantee. This requires compiling a Groth-16 zk-SNARK prover to WebAssembly and executing it client-side within the constraints of mobile hardware.

== Impact

ZeroVerify has implications across three dimensions. Economically, it targets markets where identity over-disclosure is endemic: the student discount market (\$19.3B by 2033) and age verification market (\$1.2B by 2028), where users currently surrender full identity documents to prove a single attribute. Legally, GDPR and CCPA both mandate data minimization; ZeroVerify satisfies that requirement at the protocol level rather than through organizational policy. The EU's May 2024 digital identity regulation explicitly requires zero-knowledge proofs, which independently validates the technical approach. Socially, users stop surrendering identity documents for routing verifications. The credential stays on the device. The verifier learns one bit: valid or invalid.

= Product Definition

ZeroVerify is a privacy-centered verification platform that lets users confirm eligibility claims, like student status or age requirements, without exposing unnecessary personal information. The system is designed to reduce identity data exposure while still providing secure and reliable verification for online services.

ZeroVerify integrates with trusted Identity Providers (IdPs or Keycloak) through standard authentication protocols. After a user signs in, the platform receives verified information needed to issue a credential, then issues and signs that credential and delivers it to the user for local storage.

When a verifier requests verification, the request maps to a specific *proof type*, which corresponds to a specific *circuit* that ZeroVerify supports. The circuit determines exactly what becomes public versus private in the proof, meaning the user is not choosing arbitrary attributes to reveal. Instead, the user reviews the requested proof type (circuit) and either approves or denies generating that proof. The verifier receives a simple Accepted/Rejected result and does not gain access to the user's full identity data.

Overall, ZeroVerify focuses on data minimization, user consent at the proof-type level (circuits), and compatibility with existing identity systems.

= Target Audience (Primary users + pain points)

*Primary: Verifiers (merchants, websites, service providers)* who need to confirm a single eligibility claim (ex: student status, over-21) but do not want to collect or store personal identity data.

Pain points:
- Existing verification methods often require collecting full identity attribute sets even when only one yes/no claim is needed.
- Storing identity data increases breach risk, compliance burden, and long-term liability.
- Manual verification or document uploads are slow, high-friction, and easy to abuse.

*Secondary: End users (students/individuals)* who want to prove eligibility without oversharing personal details.

Pain points:
- Users are forced to share more personal info than necessary for simple checks.
- Users have limited control over how long a verifier retains their data.

*Supporting: Institutions/IdPs (universities/enterprises)* that already run identity infrastructure and prefer solutions that do not require major changes.

Pain points:
- They do not want to replace or rework existing SAML/OAuth/OIDC setups to support selective disclosure.

= User Goals (What they are trying to achieve)

*Verifier goals:*
- Confirm an eligibility claim with a simple result (valid/invalid) during a real-time flow.
- Reduce the amount of personal data they collect, store, and are responsible for.
- Prevent reuse/replay of verification attempts and reduce fraud.

*End user goals:*
- Prove a claim (student/over-21) without revealing unnecessary personal attributes.
- Understand what is being requested and approve or deny before proof generation.
- Complete verification quickly with minimal steps.

*Institution/IdP goals:*
- Support verification using existing identity infrastructure without new protocol changes.
- Avoid adding additional identity-data distribution pathways.

= Minimum Viable Product (MVP)

For the initial launch/demo, ZeroVerify will support one end-to-end verification flow with at least one proof type (e.g., student status).

*Core requirements and features:*
- *Issuance via existing IdP (Keycloak broker):* User authenticates through an institution IdP via Keycloak, and ZeroVerify issues a signed credential.
- *Credential storage in user wallet:* Credential is delivered to the user and stored in their wallet/client (not stored centrally as raw identity data).
- *Verifier challenge + proof request:* Verifier requests a supported proof type and sends a fresh challenge.
- *User consent:* User reviews the request and approves/denies proof generation.
- *Proof generation (supported proof type):* User generates a proof for the requested proof type.
- *Verification result:* Verifier receives a clear valid/invalid result.
- *Replay protection:* Proof is bound to the verifier challenge to prevent reuse across attempts.
- *Revocation checking (if included in demo scope):* Verification includes a check against credential revocation status.

= Functional Requirements

== User Requirements

=== Credential Issuance (User + IdP)
- User logs in using a trusted identity Provider (IdP)
- User receives a digital credential in their wallet
- User can view their credentials inside their wallet

=== Verifier Request Proof (Website/Store)
- Verifier requests a specific attribute (e.g. "Over 21")
- Verifier sends a Nonce/challenge to user's credentials wallet
- Verifier receives a proof result ('Valid" or "Invalid")

=== User Generates ZK Proof
- User receives a notification about a proof request
- User view which type of proof the verifier requests
- User can accept or decline the request
- User generates a ZK proof that only reveals the requested attributes
- User sends the proof back to the verifier

=== Proof Verification (Verifier)
- Verifier submits the received proof for validation
- Verifier receives a confirmation if the proof is valid
- Verifier sees if the credential is revoked or still active
- Verifier decides to approve or deny based on the result

=== Security and Access Control
- The system shall protect credentials, proofs, cryptographic keys in storage and during transmission
- The system shall ensure that only authorized verifiers can request credentials, generate proof, or verify proofs
- The system shall detect and reject tampered, invalid, or malformed proofs during verification
- The system shall support key management practices, including key rotation and least-privilege access
- The system shall not persist raw identity attributes received from an identity provider. The system shall persist only a non-reversible cryptographic derivative of the subject identifier for the purpose of preventing duplicate credential issuance

== Functional Logic

A logical blueprint for how the system responds to user inputs.

=== Digital Credential Issuance
- When User logs with an IdP, the system validates authentication
- If authentication succeeds, the IdP returns verified attributes
- System creates a BBS+ signed credential using those attributes
- The Signed credential is sent to user's wallet via secure channel

=== Attribute Proof Request
- When a verifier requests an attribute, the system builds a "proof request" object
- The system includes:
  - Circuit Type
  - Verifier ID
  - Unique Challenge
- The request is delivered to the user's wallet

=== User Consent & ZK proof
- Wallet displays requested attributes
- If user declines, the system returns consent_denied
- If user approves:
  - A ZK proof is generated tied to verifier challenge

=== Proof Verification
- Verifier submits the ZK proof + challenge + Public input
- System checks:
  - Proof Structure is valid
  - Cryptographic correctness
  - Challenge matches (anti replay)
  - Credential status revocation list
- If all checks pass return "valid"
- If any step fails return "invalid" with error code

= Non-Functional Requirements

== Privacy
- The system shall not persist raw identity attributes received from an identity provider
- The system shall support selective disclosure by revealing only attribute(s) required by the requested proof type
- Each generated proof shall include a non-reversible cryptographic identifier derived from the subject's identity as a public output. This identifier shall be consistent across all proofs generated from the same credential. No other public output field in a generated proof shall be consistent across separate verification sessions originating from the same credential

== Performance
- The system should generate ZK proofs in 1-5 seconds under normal load
- The system should allow verifiers to validate proofs quickly enough for real-time checkout/discount flows

== Scalability
- The system should support growth in the number of users, issuers/IdP, and verifiers without significant performance degradation
- The System should scale verification workloads to handle proof requests and validations
- The system should keep verification and revocation-checking mechanism efficient at large scale

== Usability
- The system should provide a simple verification experience for users with 3 user actions or fewer and clear consent prompts
- The system should provide a straightforward integration experience for verifiers with clear documentation and stable interfaces
- The system should provide clear user-friendly error messages (e.g. unsupported proof type, expired session, invalid proof)

== Reliability
- The system should remain available during verification requests and handle transient failures gracefully
- The system should fail safely (do not grant verification when proof generation or verification cannot be completed)
- The system should preserve user access to credential storage and proof generation even if non-critical services experience issues

== Interoperability
- The system should align with W3C verifiable credential standards to maximize compatibility across platforms and ecosystems
- The system should support common authentication systems used by issuers, IdP (OAuth/SSO) and work across major browsers/devices

== Maintainability
- The system should be modular so components (Issuance, proof generation, verification, replay protection) can be updated independently
- The system should include operational logging and monitoring to support debugging and maintenance without logging PII
- The system should allow policy updates (e.g., supported proof types, replay protection rules) without requiring major redesign

= UI/UX & Design Strategy

== How the user interacts with the logic

ZeroVerify's UI is designed around a simple "start → login → consent → result" flow. The user should always understand (1) what they are proving, (2) what is being shared (yes/no), and (3) when the action is complete. The UI emphasizes privacy and consent so users never feel like verification is happening "in the background."

=== Conceptual Model (the mental map we want users to have)

We want users to think of ZeroVerify like a digital yes/no stamp, not an identity-sharing process:

1. Get credential (login once with your institution through Keycloak/IdP)
2. Review request (a verifier asks for a specific proof type like "student status")
3. Approve/Deny (user controls whether the proof is generated)
4. Result (verifier receives Accepted/Rejected; user sees confirmation)

Key message shown in the UI:

Style goals: simple, professional, low-stress, privacy-first.

- *Colors:* neutral but fun background, one main accent color for primary actions, clear message for Accepted/Rejected
- *Typography:* large headings, readable body text, consistent spacing, consistent font
- *Layout:* single-purpose pages with clear titles (Select University, Login, Consent, Result)

Reusable components (used across screens):
- Primary/secondary buttons (Start, Continue, Approve, Deny)
- Cards (request summary, consent details, result panel)
- Status badges (Accepted/Rejected/Processing)
- Alerts (error + reason, warnings like "request expired")
- Loading states (spinner + short message)

=== Feedback Mechanisms (instant signals)

Users should always get immediate feedback that something is happening:

- Loading spinner + message for "Redirecting to login…" and "Generating proof…"
- Clear success state: "Proof sent" / "Verification complete"
- Clear rejection state: "Rejected" with a short reason label
- Disable buttons during processing to prevent double-clicks
- Optional sound/animation is not required; visual feedback is enough

=== Error Handling (minimize confusion and mistakes)

We reduce user mistakes by making the next action obvious and preventing "oops" clicks:

- Before action: clear labels on what's being requested (proof type) and what is shared (yes/no)
- During action: confirmation prompt before sending proof (consent screen)
- After action: show a short reason if something fails, using plain language

Example error messages (plain language):
- "Request expired — ask the verifier to try again."
- "Invalid request format — please retry."
- "Verification failed — proof could not be validated."
- "Credential revoked — this credential is no longer valid."

Prevent slips:
- Simple page flow, minimal choices per page
- Big buttons + spacing (Approve/Deny separated)
- Consistent wording (always "proof request" or always "challenge," but not both in the UI)

= Technical Constraints & Data

Ensuring the project is technically feasible.

== Data Models

Define clear relationships (1:N, N:N) and primary keys.

*Credential Table Schema:*

#table(
  columns: (auto, auto, auto),
  [*Attribute*], [*Type*], [*Role*],
  [subject], [String], [Partition key],
  [credential_id], [String (UUID)], [Sort key],
  [issue_date], [String (ISO 8601)], [Attribute],
  [expiry_date], [String (ISO 8601)], [Attribute],
  [revocation_index], [Number], [Attribute],
  [status], [String (ACTIVE or REVOKED)], [Attribute],
)

The relationship between a pseudonymous user identity and their credentials is 1:N. One partition key groups all credential records ever issued to that user under that IdP. Each individual credential is uniquely identified by cred_id as the sort key, meaning new issuance after revocation or expiry produces a new record rather than overwriting the old one.

The Issuance Lambda never touches the bitstring. It only queries the Credential table: if any record exists under the partition key with status = ACTIVE and expiry_date > now, the request is rejected, since the user can only have one active credential from a given IdP. Otherwise a new record is written with a freshly generated cred_id.

== System Architecture

ZeroVerify's architecture is split into two completely independent paths: issuance and verification. The backend is only involved in issuance. Verification happens entirely between the user's browser and the verifier, with ZeroVerify's backend never seeing what is being proved or to whom.

=== Issuance Path

The user navigates to ZeroVerify's React web app and initiates credential issuance. The app redirects to Keycloak, which federates with the user's institutional Shibboleth IdP via SAML. From the user's perspective this is a standard OAuth login flow. Once authenticated, Keycloak returns an authorization code to the React app. The app passes this code to the Issuance Lambda via API Gateway. The Lambda exchanges the code with Keycloak for a normalized OIDC claims set, computes HMAC(issuer_id || sub_id) using a key from AWS Secrets Manager, queries DynamoDB to check whether an active unexpired credential already exists for that pseudonymous identifier, and if not, signs a BBS+ verifiable credential to the React app. The credential is stored in the browser's IndexedDB and never transmitted to any server again.

=== Verification Path

The verifier generates a URL containing the proof type, their callback endpoint, and a nonce they generated themselves. The user opens this URL in their browser, landing on ZeroVerify's React web app. The app loads the credential from IndexedDB, checks whether a valid active credential exists for the requested proof type, and presents a consent screen showing exactly what is being requested and by whom. If the user consents, the app generates a Groth16 zk-SNARK proof client-side using snarkjs. The proof is posted directly to the verifier's callback endpoint. ZeroVerify's backend is not involved at any point in the verification path.

The verifier independently downloads ZeroVerify's W3C Revocation Bit String to check credentials revocation status. Both the verification key and the bitstring are public artifacts served statically. The verifier needs no API integration with ZeroVerify beyond these two static resources.

=== Revocation Path

Revocation requests are submitted to the SQS Queue via API Gateway. Those requests are processed in batches by the Revocation Lambda. The Lambda updates the credential record's status to REVOKED in DynamoDB. Lambda downloads the bitstring from the S3 and updates the values and uploads it back.

=== Component interaction

The React app talks to API Gateway over HTTPS for issuance and revocation only. It talks directly to the verifier's callback endpoint for proof submission.

== Integration Strategy

=== Identity Providers (via Keycloak)

ZeroVerify integrates with institutional identity providers through Keycloak as the federation layer. Keycloak handles all SAML complexity internally. From ZeroVerify's perspective, every IdP looks identical: a standard OIDC claims set returned after an authorization code exchange. Adding a new institution requires only configuring a new IdP in Keycloak's realm.

=== Verifier Callback Endpoint

The React app receives the verifier's callback URL as a query parameter in the verification link and posts the generated proof directly to it over HTTPS. ZeroVerify imposes no requirements on the verifier's backend beyond accepting an HTTP POST with the proof payload.

= Success Metrics & Validation

== Functional Requirements

=== Digital Credential Issuance

*Success Metrics:*
- 100% of authenticated users receive credentials
- Credentials contain all approved attributes and are visible in the wallet

*Validation Method:*
- Test with multiple IdPs and users
- Inspect wallet contents for correct attributes, signatures, and metadata

=== Attribute Proof Request

*Success Metrics:*
- Verifiers can request any supported attribute
- Proof request delivered to the user's wallet within ≤ 2 seconds

*Validation Method:*
- Simulate proof requests and confirm delivery to wallet
- Measure delivery latency

=== User Review, Consent, ZK Proof Generation

*Success Metrics:*
- Users see only requested attributes
- Proof generated correctly, revealing only requested attributes
- Proof generation time ≤ 3–5 seconds

*Validation Method:*
- End-to-end testing with sample credentials
- Verify hidden attributes remain concealed
- Measure generation time under normal load

=== Proof Verification & Revocation Check

*Success Metrics:*
- Verifier receives valid/invalid results correctly
- Revoked credentials are flagged

*Validation Method:*
- Test verification with valid, revoked, and tampered proofs
- Compare results against expected outcomes

=== Security & Access Control

*Success Metrics:*
- Unauthorized verifiers cannot request proofs
- Tampered or malformed proofs are rejected
- Credentials and proofs remain encrypted at rest and in transit
- Key rotation and access controls enforced

*Validation Method:*
- Penetration testing and access control audits
- Attempt unauthorized proof requests and tampering
- Verify encryption and key management logs

== Non-functional Requirements

=== Security

*Success Metrics:*
- Credentials, proofs, and keys are protected in storage and during transmission
- Only authorized verifiers can request credentials, generate proofs, or verify proofs
- Tampered, invalid, or malformed proofs are detected and rejected
- Secure key management practices, including key rotation and least-privilege access, are enforced

*Validation Method:*
- Conduct penetration tests and security audits
- Attempt unauthorized proof requests and tampering
- Inspect encryption and key management implementation

=== Privacy

*Success Metrics:*
- Raw personal identity data is not stored centrally
- Only requested attributes are disclosed during proof generation
- Minimal linkability across verification sessions

*Validation Method:*
- Review system architecture for centralized data storage
- Test selective disclosure with sample proofs
- Analyze session identifiers across verifiers to check linkability

=== Performance

*Success Metrics:*
- Zero-knowledge proofs are generated in ≤ 3–5 seconds under normal load
- Proof verification completes quickly enough for real-time flows (≤ 1–2 seconds)

*Validation Method:*
- Load testing with multiple concurrent users
- Measure proof generation and verification times

=== Scalability

*Success Metrics:*
- System supports growth in number of users, IdPs, and verifiers without significant performance degradation
- Verification and revocation-checking mechanisms remain efficient at large scale

*Validation Method:*
- Simulate large-scale usage scenarios
- Measure system latency and throughput under high load

=== Usability

*Success Metrics:*
- Users can complete verification in ≤ 3 actions
- Clear, user-friendly error messages are displayed
- Verifiers have straightforward integration experience

*Validation Method:*
- Conduct usability testing with representative users
- Track number of actions to complete verification
- Test integration setup and error handling flows

=== Reliability

*Success Metrics:*
- System remains available during verification requests
- System fails safely if proof generation or verification cannot be completed
- User access to credentials and proof generation is preserved even if non-critical services fail

*Validation Method:*
- Simulate transient failures and downtime
- Verify safe failure behavior
- Check user access continuity during non-critical service disruptions

=== Interoperability

*Success Metrics:*
- System aligns with W3C Verifiable Credential standards
- Supports common authentication systems and major browsers/devices

*Validation Method:*
- Test proof issuance and verification across platforms
- Verify compatibility with OAuth/SSO and different browsers/devices

=== Maintainability

*Success Metrics:*
- System components are modular and updatable independently
- Operational logging and monitoring supports debugging without logging PII
- Policy updates (proof types, replay protection rules) can be applied without major redesign

*Validation Method:*
- Review component modularity
- Inspect logging and monitoring setup
- Apply policy updates and verify correct system behavior
