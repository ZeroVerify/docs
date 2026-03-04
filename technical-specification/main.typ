#set page(
  paper: "us-letter",
  margin: (x: 1in, y: 1in),
)

#set par(justify: true)
#show link: underline
#set heading(numbering: "1.")

#align(center)[
  #text(size: 16pt, weight: "bold")[
    ZeroVerify Technical Specification
  ]

  #v(0.3em)

  #text(size: 11pt)[
    Version: 1.0 | Date: 2/15/26
  ]

  #v(0.2em)

  #text(size: 11pt)[
    Team: Lisa Nguyen (CS), Anton Sakhanovyvh (CS), Souleymane Sono (CS), Fateha Ima (CS), Simon Griemert (CS)
  ]

  #v(0.2em)

  #text(size: 10pt, style: "italic")[
    (CS) = Computer Science Major
  ]

  #v(1.5em)
]

= Product Overview (The "What")

*Problem Statement:* Existing identity verification systems require users to disclose entire credential documents (student IDs, driver's licenses) to prove a single attribute, creating unnecessary privacy exposure and centralized data liability for verifiers. ZeroVerify allows circuit-defined attributes ("I am an enrolled student," "I am over 21") to be cryptographically proven without revealing any underlying personal data.

*Target User:* The primary persona is an end user (student, individual) who holds a digitally-issued credential and needs to selectively prove specific attributes to third-party verifiers (merchants, services, platforms) without exposing their full identity. Secondary actors are institutional identity providers (universities, employers) whose OAuth/OIDC infrastructure ZeroVerify delegates to for attribute verification during issuance, and verifiers (merchants, services) who integrate ZeroVerify's open-source SDK to cryptographically validate proofs.

*Minimum Viable Product (MVP) Features:*
- *Credential Issuance:* ZeroVerify authenticates the user via the institution's OAuth/OIDC IdP, generates a W3C Verifiable Credential containing the user's attribute set, signs it with a BBS+ signature, and delivers the signed credential to the user's client for local storage.
- *Proof Generation:* The user's client runs a ZeroVerify-provided zk-SNARK circuit against their locally-stored credential. The circuit derives a boolean claim (e.g. "over 21", "is a student") from the credential's attribute set, producing a proof of that claim without revealing the underlying attributes. If the credential does not contain the data required by the circuit, proof generation fails. No credential data leaves the device.
- *Proof Verification:* A verifier uses ZeroVerify's open-source SDK to validate the zk-proof against the issuer's published verification key and checks credential revocation status against a publicly-accessible W3C Bitstring Status List that ZeroVerify hosts on S3. The cryptographic validation runs entirely on the verifier's side with no round-trip to ZeroVerify's infrastructure.

= System Architecture (The "How")

== System Diagram

#page(flipped: true)[
  #figure(
    image("system-architecture-diagram.png", width: 100%, height: 90%),
    caption: [System Architecture Diagram - All writes to S3 and DDB occur in the IAD region to avoid race conditions during replication. Inter-region arrows are omitted for clarity.]
  )
]

== Architectural Boundary

ZeroVerify is a library and issuance service, not a verification intermediary. The system provides: (1) an issuance API that issues BBS+ signed credentials, (2) a client-SDK that handles credential storage and proof generation, and (3) a verification library that verifiers embed. Verifiers interact directly with users. They only call ZeroVerify to get a W3C revocation bitstring.

== The Tech Stack

*Backend: AWS Lambda (Rust)*

The credential issuance service is implemented as a serverless Lambda function behind the API Gateway. Lambda is appropriate here because issuance is a stateless, event-driven operation with low baseline traffic and unpredictable spikes during enrollment periods. A persistent server (EC2 or ECS) would be over-provisioned at idle and require operational management that adds no architectural value for this workload. Lambda's per-invocation billing and automatic scaling match the issuance traffic pattern.

Rust was chosen over Java or other runtime options because Lambda cold start times are critical for issuance responsiveness (target < 800ms total execution). Rust Lambda functions have significantly faster cold starts (~100-300ms) compared to Java (~1-3s) and lower memory footprint. Since issuance operations involve cryptographic operations (BBS+ signing) where memory safety is critical, Rust's compile-time guarantees eliminate entire classes of vulnerabilities without runtime overhead. The BBS+ signature library ecosystem in Rust is mature, and Rust's zero-cost abstractions ensure the 6-7.5ms signature operation target is achievable without JVM garbage collection pauses.

*Database: AWS DynamoDB*

Credential metadata is stored in DynamoDB. The access pattern is entirely key-value.

*Revocation Storage: AWS S3*

The revocation bitstring (a Bitstring Status List per the W3C spec) is stored as a static object in S3 and replicated globally using S3 Cross Region Replication (CRR). The bitstring is small (1 bit per credential) so CDN is not justified.

*Client SDK: TypeScript*

The proof generation library that runs entirely in the browser. The library fetches needed keys from ZeroVerify.

*Infrastructure/IaC: Terraform/OpenTofu*

Infrastructure is defined as code for reproducible deployments and CI/CD.

== External APIs & Integrations

*University OAuth 2.0/OIDC IdP*

Used during credential issuance to authenticate the user and fetch authoritative attribute claims (enrollment status) from the IdPs' endpoint.

*AWS Secrets Manager*

The BBS+ issuer private key is stored here, since AWS KMS does not support BBS+ as it is not a NIST-standardized algorithm.

= Data Design

== Core Entities

List the 3–4 most important data objects:
- Users
- Proofs
- Credentials

== Proof Entity Schema

```json
{
  "proof_type": "age_over_21",
  "proof": "base64_zkSNARK_proof_bytes",
  "public_inputs": {
    "challenge": "n-0S6_WzA2Mj",
    "credential_status_index": 94567
  }
}
```

== Credential Entity Schema

```json
{
  "student_id": "G89u28394",
  "email": "anton@oakland.edu",
  "first_name": "Anton",
  "last_name": "Sakhanovych",
  "birthdate": "2000-05-15",
  "custom_claims": {
    "student_status": "enrolled",
    "enrollment_date": "2021-09-01",
    "university": "Oakland University",
    "major": "Computer Science"
  }
}
```

== Data Schema

*Relationships:*
- One user can have multiple different credentials. Specifically, they can draw their credentials from different sources (e.g. University, Job, Government). However, they will only have one unique `idp_unique_id`.
- One user can generate many different proofs
- Each signed credential can be used to generate many proofs

*Credential Metadata Table:*

```json
{
  "subject_id": "did:key:z6MkF5rGMoatr...",
  "credential_id": "https://api.zeroverify.com/credentials/a3f8b2c1-4d5e-6f7a-8b9c-0d1e2f3a4b5c",
  "credential_type": "Student_Credential",
  "issued_at": "2025-02-10T20:41:27Z",
  "expiresAt": "2026-02-10T20:41:27Z",
  "revocation_index": 94567,
  "revoked": false
}
```

== Storage Strategy

The files will be stored in AWS S3 and metadata about issued credentials will be in AWS DynamoDB.

= Technical Complexity & Depth

== The "Hard" Part

*Integrating with existing Authentication protocols*

OAuth/OIDC protocol variability: institutions use different implementations with varying standards compliance, attribute formats.

*Designing Efficient and expressive zk-SNARK circuit*

Designing circuits that prove boolean claims (e.g "Over 21", "is student") without revealing any underlying attributes.

*Revocation consistency and batch processing*

The core challenge is preventing race conditions when multiple Lambda functions concurrently process revocation requests. For example: 1000 users generate revocation requests → SQS queue batches them (100 requests/batch) → lambda reads S3 bitstring, modifies bits for all 100 requests, write back to S3. However, concurrent lambda invocations reading and writing the same S3 file create race conditions where revocation updates can be lost or overwritten. The solution is implementing optimistic locking or atomic update mechanism to ensure all revocation bit flips are captured under high concurrency.

== Performance Goals

=== Credential Issuance
- OAuth/OIDC authentication < 500ms
- Lambda execution for credential generation < 800ms
- BBS+ signature Operation: 0.3 - 7.5ms per credential
- DynamoDB write: 20ms
- Credential delivery to user: 200ms

=== Client-Side Proof Generation Performance
- zk-SNARK Circuit Execution
  - Target: < 4 seconds for proof generation

=== Proof Verification
- Target: < 300ms for complete verification
  - Cryptographic zk-proof validation < 150ms
  - BitString retrieval from S3 < 100ms

=== BBS+ Signature Operation
- Credential signing: 6-7.5ms
- Proof Generation: 1-2ms
- Proof Verification: 19ms/zk proof

=== Revocation Processing
- Revocation Update Latency: < 10 min from revocation request to global availability
- Batch Processing:
  - Process 100 revocations requests/batch
  - Lambda execution time: < 3s/batch
  - S3 upload < 1 second
- Race condition Handling:
  - Target: 99.9% consistency for concurrent revocation update
  - Use DynamoDB conditional writes or optimistic locking

= Resilience & Security

== Error Handling

- If the OAuth IdP fails or times out, the system returns HTTP 503 and prompts the user to retry.
- If the revocation list cannot be retrieved, the system denies verification rather than approving the proof.
- The system implements a circuit breaker approach:
  - After repeated external API failures, requests temporarily fail fast instead of waiting for long timeouts.
  - The system retries after a cooldown period.
- ZeroVerify follows a fail-safe policy: verification is never approved if validation cannot be fully completed.

== Security

- All communication between users, verifiers, and ZeroVerify uses HTTPS (TLS 1.2+).
- Server-side data (DynamoDB and S3) is encrypted using AWS KMS.
- ZeroVerify does not store raw PII after credential issuance.
- Credentials are stored locally in the user's browser and are not transmitted to ZeroVerify unless generating a proof.
- Each proof is bound to a verifier-provided session nonce to prevent replay attacks.
- Session identifiers expire after a fixed time window (e.g., 5 minutes).
- The verification API validates:
  - Proof structure
  - Cryptographic validity
  - Issuer signature
  - Revocation status
- IAM roles follow least privilege principles.
- API keys and signing keys are stored in AWS Secrets Manager and are never hardcoded in source code.
- The system never returns "valid" if verification fails or is incomplete.

= Milestone Roadmap (The "When")

== Phase 1 (Weeks 1-3): Prototype Implementation

=== Infrastructure + Database Schema + Issuance Skeleton (API endpoints)
- Set up basic infrastructure so the demo can run end-to-end (frontend + backend running).
- Create the minimal database schema needed for the demo (credential storage + proof session/challenge tracking).
- Set up Keycloak identity middleware (login/authentication) and connect it to our backend.
- Stand up the issuance API skeleton (endpoints exist and respond):
  - POST /api/credentials/request (start issuance)
  - POST /api/idp/mock-login (mock IdP auth)
  - POST /api/credentials/issue (issue/store credential)

=== Trusted Setup (required before credential generation + proofs)
- Run a trusted setup to generate the setup parameters/files needed for our circuits so credential-related proof generation and verification can work.
- Deploy verification and proving key to the S3

=== Credential Issuance Flow
- Backend generates the credential and returns it to the web app, and the credential is stored locally in the user's browser
- The user clicks "Request Credential" on our web app to start issuance.
- Create a mock verifier.

=== Replay Protection (session nonce/challenge binding)
- Generate a unique session challenge (session nonce) per verification attempt and bind it to the proof (handled as part of the circuit).
- Demo check: attempt to reuse an old proof in a new session → should be rejected.

=== Proof Generation + User Consent (at least 1 proof type)
- Proof request is shown in our web app and the user must approve/deny.
- On approval, generate a proof for one proof type (ex: student status or over 21).

=== Verifier Verification Flow (Accepted/Rejected) (last step)
- Verify proof using issuer public key + public inputs.
- Return Accepted/Rejected and log basic non-PII debug info.

== Phase 4 (Week 4-6): Hardening + UI + Testing

Goal: Done by April 13

=== Error handling + clear rejection reasons
- Add clear rejection reasons: *invalid*, *malformed*, *revoked*, *expired*
  - *Invalid:* proof doesn't verify
  - *Malformed:* missing/wrong format
  - *Revoked:* credential was disabled
  - *Expired:* session/challenge/credential expired (if applicable)

=== Revocation checking (if in scope for demo)
- Add a revocation check during verification
- Demo case (if implemented): revoked credential → rejected

=== UI polish for demo flow
- Simplify the demo screens and prompts
  - clear "Approve/Deny" consent step
  - clear "Accepted/Rejected" result screen

=== Testing plan + test cases
- Happy path: request → approve → proof generated → verify → accepted
- Failure cases: replay attempt, malformed input, invalid proof (and revoked/expired if implemented)

== Phase 5 (Week 7-Finals): Final Checklist + Demo Prep

=== Deployment/demo packaging + documentation cleanup
- Decide demo format: hosted or local run
- Create simple "how to run" steps so any teammate can launch the demo
- Cleanup documentation so it matches what we actually built

=== Final deliverables prep
- Finalize website/video (if required)
- Lock demo script + slide updates (who presents what, demo steps)

=== Final product demo (Finals Week)
- Final rehearsal + backup plan (in case something breaks)
- Deliver final demo during finals week

= Limitations and Tradeoffs

*Credential Revocation*

We implement #link("https://www.w3.org/TR/vc-bitstring-status-list/")[W3C Bitstring Status Lists] rather than PKI mechanisms (CRL/OCSP) because bitstrings preserve verification privacy. #link("https://datatracker.ietf.org/doc/html/rfc5280")[CRL] requires merchants to download lists of revoked credential identifiers, creating linkability. #link("https://en.wikipedia.org/wiki/Online_Certificate_Status_Protocol")[OCSP] requires real-time queries with credential identifiers, exposing verification patterns. Bitstrings encode revocation as bit positions in a compressed list; merchants fetch the bitstring, check the relevant bit locally, reveal nothing about which credential they're verifying. Users self-revoke by generating ZK proofs of credential ownership. Time-based expiration handles normal lifecycle without revocation overhead.

*Proof Generation Cost*

Generating ZK Proofs takes 2-5 seconds on modern devices. This is more compute-intensive than submitting a SheerID form. However, it is faster than uploading the document and waiting for manual approval. The computational cost shifts from servers to user's device.

*Browser Security vs Apple's hardware wallet*

Browser-based credentials storage is less secure than Apple's secure element. However, our architecture never transmits the credentials. Credentials always stay on the device, and only ZK proofs are sent. Even if someone compromises browser storage, they get only one user's credentials, not a centralized database of millions. Apple's approach is more secure, but their selective disclosure still sends identity data. We trade hardware-level security for zero data disclosure.

*Trust*

Merchants trust our mechanism through cryptographic verification, not reputation. The ZK proof is mathematically verifiable using our public key; if it verifies, the credential was genuinely issued by us and hasn't been tampered with. We issue credentials only after OAuth confirmation from the authoritative source; the issuer is the source of truth, not us. Merchants can audit our public key and verification code for transparency. SheerID offers broader coverage through #link("https://www.sheerid.com/press-releases/sheerid-expands-identity-verification-platform-with-marketing-hub-and-dataconnectors-to-400-martech-solutions/")[200,000+ data sources] but requires collecting excessive user data. We offer cryptographic certainty with zero data collection. Initial adoption requires pilots with privacy-conscious brands.

#pagebreak()

= Reference links for performance Benchmarks

- #link("https://news.dyne.org/benchmark-of-the-bbs-signature-scheme-v06/")
- #link("https://identity.foundation/bbs-signature/draft-irtf-cfrg-bbs-signatures.html")
- #link("https://arxiv.org/abs/2512.10020")
- #link("https://www.w3.org/TR/vc-data-model/")
