# Zero-Knowledge Identity System

## USE CASES

### UC-1: Issue Digital Credential
**Primary Actor:** ZeroVerify (Issuer Service)

**Description:**
The user requests a credential from ZeroVerify. The user authenticates with a trusted IdP (e.g., university, government, employer). The IdP provides verified attributes to ZeroVerify, and ZeroVerify generates a digital credential containing those attributes, signs it using a BBS signature, and delivers it to the user during the issuance session.

---

### UC-2: Request Attribute Proof
**Primary Actor:** Verifier (Store / Website / Service)

**Description:**
The verifier requests proof of a supported proof type (e.g., over 21 or student status) by sending a challenge that includes the proof type and a fresh session identifier.

---

### UC-3: Review Request, Consent, and Generate ZK Proof
**Primary Actor:** User

**Description:**
The user reviews the verifier’s challenge, sees what proof type is being requested and what attribute(s) it reveals, and approves or denies proof generation. If approved, the system generates a zero-knowledge proof of possession of a valid BBS-signed credential that reveals only the attribute(s) required by that proof type and hides all other identity information.

---

### UC-4: Verify Proof (including revocation check)
**Primary Actor:** Verifier

**Description:**
The verifier submits the proof for verification and receives a result. The verification process accepts a proof only if it is cryptographically valid and the referenced credential is not revoked (if revocation is supported). The verifier rejects proofs that are invalid, malformed, expired/out-of-policy, or tied to a revoked credential.

---

## FUNCTIONAL REQUIREMENTS

### Zero-Knowledge Identity System (BBS Signatures)

### FR-1: Credential Issuance
The system shall allow a user to request a digital credential.
The system shall require the user to authenticate with a trusted IdP, and shall accept verified attributes from that IdP.
The system shall generate a digital credential containing verified attributes and sign it using a BBS signature.
The credential format should follow an existing standard (e.g., W3C Verifiable Credentials) for interoperability.
The system shall deliver the signed credential to the user during the issuance session.

---

### FR-2: Selective Disclosure Proof Generation
The system shall allow a user to generate a zero-knowledge proof of possession of a valid BBS-signed credential.
The system shall reveal only the attribute(s) required by the requested proof type and hide all other identity information.
The system shall support proof generation only for predefined proof types (e.g., student status, over 21), rather than arbitrary user-selected attributes.

---

### FR-3: User Consent and Proof-Type Review
The system shall allow the user to review a verifier’s challenge before any proof is generated.
The system shall display the requested proof type and the attribute set that will be revealed by that proof type.
The system shall allow the user to approve or deny proof generation based on the disclosed attribute set.

---

### FR-4: Proof Verification and Result Criteria
The system shall provide a verification interface/library that accepts a zero-knowledge proof along with all required public inputs for the proof's circuit.
The interface/library shall return:
1. Cryptographic validity status (valid or invalid)
2. Error information for invalid cases (malformed proof, cryptographically invalid)

The interface/library shall provide utilities to check credential revocation status against the system's published revocation lists.

Verifiers integrate this library to validate proofs and make accept/reject decisions based on the validity results and revocation status.

---

### FR-5: Session Binding and Replay Protection
The system shall bind each proof to a verifier-provided challenge/session identifier so the proof cannot be reused across different verification attempts.
The system shall require a fresh verifier challenge/session identifier for each verification attempt.

---

### FR-6: Proof Generation Failure Handling
The system shall detect and reject proof generation when required conditions are not met (e.g., expired credential, unsupported proof type, missing required attributes).
The system shall return a clear failure message and shall not produce a proof in those cases.

---

## USER STORIES

### US-1: Receive Digital Credential
As a user, I want to receive a digitally signed credential from ZeroVerify after authenticating with a trusted issuer/IdP, so that I can later prove identity attributes without showing my physical ID.

### US-2: Prove an Attribute with Selective Disclosure
As a user, I want to generate a zero-knowledge proof for a supported proof type that reveals only the required attribute(s), so that my other personal information remains private.

### US-3: Control Consent and Disclosure
As a user, I want to review a verifier’s request and approve or deny proof generation before anything is shared, so that I stay in control of what attribute(s) are disclosed.

### US-4: Verify a Proof as a Service Provider
As a verifier, I want to validate a submitted proof and receive an Accepted or Rejected result, so that I can enforce policies without collecting personal data.

### US-5: Prevent Proof Reuse
As a verifier, I want each proof to be tied to a unique challenge/session identifier, so that previously used proofs cannot be replayed.

---

## NON-FUNCTIONAL REQUIREMENTS

### NFR-1: Security
The system shall protect credentials, proofs, and keys in storage and during transmission.
The system shall ensure only authorized actors can request credentials, generate proofs, or verify proofs.
The system shall detect and reject tampered, invalid, or malformed proofs during verification.
The system should support secure key management practices such as key rotation and least-privilege access.

---

### NFR-2: Privacy
The system shall avoid centralized storage of raw personal identity data when possible.
The system shall support selective disclosure by revealing only the attribute(s) required by the requested proof type.
The system should reduce linkability across verification sessions to limit tracking across verifiers.

---

### NFR-3: Performance
The system should generate zero-knowledge proofs within a few seconds under normal load.
The system should allow verifiers to validate proofs quickly enough for real-time checkout/discount flows.

---

### NFR-4: Scalability
The system should support growth in the number of users, issuers/IdPs, and verifiers without significant performance degradation.
The system should scale verification workloads to handle concurrent proof requests and validations.
The system should keep verification and revocation-checking mechanisms efficient at large scale.

---

### NFR-5: Usability
The system should provide a simple verification experience for users with minimal steps and clear consent prompts.
The system should provide a straightforward integration experience for verifiers with clear documentation and stable interfaces.
The system should provide clear, user-friendly error messages (e.g., unsupported proof type, expired session, invalid proof).

---

### NFR-6: Reliability
The system should remain available during verification requests and handle transient failures gracefully.
The system shall fail safely (do not grant verification when proof generation or verification cannot be completed).
The system should preserve user access to credential storage and proof generation even if non-critical services experience issues.

---

### NFR-7: Interoperability
The system should align with W3C Verifiable Credential standards to maximize compatibility across platforms and ecosystems.
The system should support common authentication systems used by issuers/IdPs (e.g., OAuth/SSO) and work across major browsers/devices.

---

### NFR-8: Maintainability
The system should be modular so components (issuance, proof generation, verification, replay protection) can be updated independently.
The system should include operational logging and monitoring to support debugging and maintenance without logging PII.
The system should allow policy updates (e.g., supported proof types, replay protection rules) without requiring major redesign.

