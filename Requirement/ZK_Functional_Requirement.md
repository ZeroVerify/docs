# Zero-Knowledge Identity System

## USE CASES

### UC-1: Issue Digital Credential

### **Primary Actor**: Issuer (Government / University)

**Description**:
### The issuer creates a digital credential containing user attributes (e.g., age flags, student status) and signs it using a BBS signature before delivering it to the user.

### UC-2: Request Attribute Proof

### **Primary Actor:** Verifier (Store / Website / Service)

**Description:**
### The verifier requests proof of a specific attribute (e.g., over 21 or student status) by sending a proof request containing required claims and a session nonce.

### UC-3: Approve Proof Request

### **Primary Actor:** User

**Description:**
### The user reviews the verifier’s request, selects the attribute to disclose, and consents to generate a zero-knowledge proof derived from the BBS-signed credential.

### UC-4: Generate ZK Proof 

### **Primary Actor:** User

**Description:**
### The system generates a zero-knowledge proof of possession of a valid BBS-signed credential while revealing only the requested attribute and hiding all other identity information.

### UC-5: Verify Proof

### **Primary Actor:** Verifier

**Description:**
### The verifier validates the received proof using the issuer’s public key and the session nonce, then receives a verification result (Valid / Invalid).

## FUNCTIONAL REQUIREMENTS

### Zero-Knowledge Identity System (BBS Signatures)

### 🔵 FR-1: Credential Issuance

### The system shall allow a trusted issuer to issue a digital credential containing multiple identity attributes and sign it using a BBS signature.

### 🟢 FR-2: Selective Disclosure Proof Generation

### The system shall allow a user to generate a zero-knowledge proof of possession of a valid BBS-signed credential while revealing only the requested attribute and hiding all other identity information.

### 🟡 FR-3: User Consent and Attribute Selection

### The system shall allow the user to review a verifier’s proof request and explicitly approve or deny the disclosure of specific attributes before any proof is generated.


### 🟣 FR-4: Proof Verification

### The system shall allow a verifier to cryptographically validate a submitted zero-knowledge proof and receive only a verification result (Valid or Invalid)

### 🔴 FR-5: Session Binding and Replay Protection
### The system shall bind each zero-knowledge proof to a verifier-provided challenge or session identifier to prevent proof reuse across different verification attempts.


## User Stories

### 🟦 US-1: Receive Digital Credential

## As a user, I want to receive a digitally signed credential from a trusted issuer, so that I can later prove identity attributes without showing my physical ID.

### 🟩 US-2: Prove an Attribute with Selective Disclosure

## As a user, I want to generate a zero-knowledge proof that reveals only a required attribute (such as being over 21), so that my other personal information remains private.

### 🟨 US-3: Control Consent and Disclosure

### As a user, I want to review and approve proof requests before any information is shared, so that I stay in control of what attributes are disclosed.

### 🟪 US-4: Verify a Proof as a Service Provider

### As a verifier, I want to validate a zero-knowledge proof and receive only a Valid or Invalid result, so that I can enforce policies without collecting personal data.

### 🟥 US-5: Prevent Proof Reuse


### As a verifier, I want each proof to be tied to a unique session or challenge, so that previously used proofs cannot be replayed.


## NON-FUNCTIONAL REQUIREMENTS

### 🟢 NFR-1: Security
### The system shall protect credentials, proofs, and keys using secure storage and encrypted communication channels.
### The system shall ensure only authorized actors can request, generate, or verify proofs.
### The system shall prevent credential/proof tampering and detect invalid or modified proofs during verification.
### The system should support secure key management practices such as key rotation and least-privilege access.

### 🟢 NFR-2: Privacy
### The system shall minimize data collection and avoid centralized storage of raw personal identity information.
### The system shall support selective disclosure by revealing only the requested attribute(s) and hiding all other identity data.
### The system should reduce linkability across verification sessions to limit tracking across verifiers.

### 🟢 NFR-3: Performance
### The system should generate zero-knowledge proofs within a few seconds under normal load.
### The system should allow verifiers to validate proofs quickly enough for real-time checkout/discount flows.

### 🟢 NFR-4: Scalability
### The system should support growth in the number of users, issuers, and verifiers without significant performance degradation.
### The system should scale verification workloads to handle concurrent proof requests and validations.
### If revocation or fraud controls are implemented, the mechanism should remain efficient at large scale.

### 🟢 NFR-5: Usability
### The system should provide a simple verification experience for users with minimal steps and clear consent prompts.
### The system should provide a straightforward integration experience for verifiers with clear documentation and stable interfaces.
### The system should provide clear, user-friendly error messages (e.g., unsupported issuer, expired session, invalid proof).

### 🟢 NFR-6: Reliability
### The system should remain available and functional during verification requests and handle transient failures gracefully.
### The system shall fail safely (ex. do not grant verification when proof generation/verification cannot be completed).
### The system should preserve user access to credentials/proof generation even if non-critical services experience issues.

### 🟢 NFR-7: Interoperability
### The system should align with W3C Verifiable Credential standards to maximize compatibility across platforms and ecosystems.
### The system should support common authentication systems used by issuers (ex. OAuth/SSO) and work across major browsers/devices.

### 🟢 NFR-8: Maintainability
### The system should be modular so components (issuance, proof generation, verification, replay protection) can be updated independently.
### The system should include operational logging and monitoring to support debugging and maintenance without logging PII.
### The system should allow policy updates (ex. replay protection rules) without requiring major redesign.
