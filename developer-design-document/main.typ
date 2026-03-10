#set page(
  paper: "us-letter",
  margin: (x: 1in, y: 1in),
)

#set par(justify: true)
#show link: underline
#set heading(numbering: "1.")

#align(center)[
  #text(size: 16pt, weight: "bold")[
    ZeroVerify --- Development Design Document
  ]

  #v(0.3em)

  #text(size: 11pt)[
    Version: 1.0 | Date: 3/6/26
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

= Project Overview

== Problem Summary

Existing identity verification systems require users to disclose entire credential documents (student IDs, driver's licenses, employment records) to prove a single attribute, creating unnecessary privacy exposure and centralized data liability for verifiers. For a \$5 student discount, users upload driver's licenses to third-party verification platforms like SheerID, exposing full name, birthdate, address, and photo. Seniors proving age eligibility, employees accessing corporate benefits, and professionals showing licensure face the same problem: verification requires exposing identity data that services do not need. Apple's Digital ID uses selective disclosure, which reveals some real identity data (actual birthdate, university name) to merchants but hides other fields. Merchants still receive enough information to track and profile users across services.

The dominant protocols in use today (SAML, OAuth, OpenID Connect) are designed to transmit full identity attribute sets rather than selective proofs of individual claims. An organization verifying student status receives a name, institutional affiliation, date of birth, and email address because that is what the protocol delivers. When systems built on these protocols are breached, the exposed records reflect everything the protocol required them to collect.

== Requirements / Goals

This system addresses the following functional requirements:

*Credential Issuance Requirements:*
- User authenticates via trusted Identity Provider (IdP) using OAuth/OIDC
- System validates authentication and receives verified attributes from IdP
- System creates a signed credential using verified attributes
- Signed credential is delivered to user's wallet for local storage
- User can view their credentials inside their wallet

*Proof Generation Requirements:*
- Verifier redirects user to ZeroVerify with requested circuit type, challenge nonce, verifier ID, and callback URL
- User views which proof type the verifier requests (circuit-defined attribute such as "student status" or "over 21")
- User can approve or decline the request
- User generates zero-knowledge proof that reveals only the requested attribute without disclosing underlying personal data
- Proof is bound to verifier-provided challenge nonce to prevent replay attacks
- ZeroVerify website delivers proof and public signals to verifier's registered callback URL

*Verification Requirements:*
- Verifier constructs a proof request with specific circuit type and nonce, and redirects user to ZeroVerify
- Verifier receives proof and public signals at their registered callback URL
- Verifier locally checks proof structure, cryptographic correctness, challenge match (anti-replay), and credential revocation status using ZeroVerify's verification library
- Verifier receives clear result: "valid" or "invalid"
- Verifier decides to approve or deny based on result

*Security Requirements:*
- Protect credentials, proofs, and cryptographic keys in storage and during transmission
- Ensure only authorized verifiers can request credentials and verify proofs
- Detect and reject tampered, invalid, or malformed proofs during verification
- Support key management practices including key rotation and least-privilege access
- Do not persist raw identity attributes received from identity provider (persist only non-reversible cryptographic derivative of subject identifier to prevent duplicate credential issuance)

*Privacy Requirements:*
- Support selective disclosure by revealing only attribute(s) required by requested proof type
- Generated proofs include non-reversible cryptographic identifier derived from subject's identity as public output, consistent across all proofs from same credential
- No other public output field in generated proof is consistent across separate verification sessions

== System Boundaries (Non-Goals)

The following features are explicitly out of scope for the minimum viable product:

- *Multiple Credentials per Institution:* Users can hold only one active credential per identity provider at a time, enforced by a pseudonymous identifier derived from the subject's verified attributes. This ensures uniqueness without storing or exposing raw identity data.

- *Credential Updates or Amendments:* Once issued, credentials cannot be updated or amended. Changes require revocation and re-issuance. In-place updates are not supported.

- *User-Defined Proof Types:* Only pre-defined proof types with corresponding circuits are supported. Users cannot create custom proof types or arbitrary attribute combinations.

- *Mobile Native Applications:* The MVP is browser-based (TypeScript/React). Native iOS and Android apps are not in scope.

- *Self-Revocation by Users:* Revocation in MVP is handled through backend submission with proof of credential ownership. User-initiated self-service revocation UI is deferred.

- *Cross-Platform Credential Sync:* Credentials stored in one browser are not automatically synced to other devices or browsers. Cross-device sync is not supported.

- *Offline Proof Generation:* Proof generation requires internet access to fetch circuit proving keys from S3. Offline operation is not supported.


- *Verifier Reputation or Discovery:* The system does not provide verifier reputation scores, whitelists, or discovery mechanisms. Users are responsible for trusting verifier identity.

- *Granular Role-Based Credentials:* Each credential has a defined type (e.g., university_student, employment) that determines which proof circuits it can satisfy. A credential may be used with any circuit whose required fields are covered by that credential type. Credentials bundling complex role hierarchies or attributes spanning multiple identity providers are out of scope.

== Solution Summary

ZeroVerify is a privacy-preserving identity verification layer that integrates with the identity infrastructure universities and enterprises already operate. The system eliminates attribute disclosure entirely from the verification event.

The system works in two phases:

*Issuance Phase:* ZeroVerify federates with an institution's existing IdP via Keycloak acting as an identity broker. The institution requires no modification; from its perspective, Keycloak is a standard service provider. ZeroVerify's issuance layer extracts verified attributes from the claims set and produces a Baby Jubjub EdDSA signed verifiable credential with individual field signatures, which is delivered to and stored in the user's browser wallet. The raw credential never leaves the device after this point.

*Verification Phase:* A verifier redirects the user to ZeroVerify with a challenge nonce, requested circuit type, and a registered callback URL (e.g., "Is this person over 21?" or "Is this person an active student?"). The user's wallet uses the stored credential as a private witness to a zk-SNARK circuit specific to that claim type. The circuit produces a cryptographic proof that the claim is true without encoding any attribute value in the proof output. The proof and public signals are delivered to the verifier's registered callback URL. The verifier passes the proof to ZeroVerify's verification library, which checks cryptographic correctness, confirms the challenge nonce, and checks revocation status against a W3C Bitstring Status List. The verifier receives a single result: valid or invalid. No name, no birthdate, no institutional affiliation, no personal data of any kind is transmitted to the verifier at any point in this flow.

This directly addresses the requirements by: (1) enabling credential issuance without replacing institutional IdPs, (2) ensuring proofs reveal only circuit-defined boolean claims rather than raw attributes, (3) providing cryptographic verification with replay protection, and (4) storing credentials locally on the user's device rather than centrally.

= High-Level Design

== System Diagram

#page(flipped: true)[
  #figure(
    image("system-architecture-diagram.png", width: 95%, height: 100%),
    caption: [System Architecture with Communication Protocols - Every arrow is labeled with the specific integration protocol (REST, WebSockets, OAuth 2.0, HTTPS). All writes to DDB and S3 occur in the IAD region to prevent replication race conditions.]
  )
]

== Component Descriptions

=== Browser Wallet (TypeScript/React)

==== Purpose

The browser wallet is the user-facing application that stores credentials locally, presents verifier-initiated proof requests to users upon redirect, generates zero-knowledge proofs client-side, and delivers proofs to the verifier's callback URL. The wallet ensures credentials never leave the user's device.

==== Requirements Supported

- User can view their credentials inside their wallet
- User receives proof request notification from verifier
- User views which proof type the verifier requests
- User can approve or decline the request
- User generates zero-knowledge proof that confirms only the requested boolean claim without revealing the underlying attribute value
- Proof is bound to verifier-provided challenge nonce to prevent replay attacks
- Credentials are stored locally on user's device rather than centrally

==== Detailed Design

The wallet is implemented as a React single-page application (SPA) hosted on S3 with CloudFront distribution. Credentials are stored in the browser's IndexedDB, encrypted using the Web Crypto API with a key derived from the user's passphrase. The proof generation library runs entirely in the browser using snarkjs compiled to WebAssembly.

The wallet architecture separates concerns into three main modules:

1. *Credential Storage Module:* Interfaces with IndexedDB for encrypted credential persistence
2. *Proof Generation Module:* Executes zk-SNARK circuits using snarkjs and WebAssembly
3. *UI Module:* Renders credential views, consent screens, and verification results

==== Visual Workflow / Diagram

*Credential Issuance Flow:*
1. User clicks "Request Credential" button
2. Wallet redirects to Keycloak OAuth endpoint with PKCE challenge
3. User authenticates with university IdP
4. Keycloak returns authorization code
5. Wallet calls Issuance Lambda with authorization code
6. Lambda returns signed Baby Jubjub EdDSA credential
7. Wallet encrypts and stores credential in IndexedDB
8. Wallet displays credential in UI

*Proof Generation Flow:*
1. User opens verifier link with proof request parameters
2. Wallet parses URL parameters (proof_type, verifier_id, challenge, callback_url)
3. Wallet displays consent screen showing what is being requested
4. User clicks "Approve"
5. Wallet loads credential from IndexedDB
6. Wallet fetches circuit proving key from S3
7. Wallet generates zk-SNARK proof using snarkjs
8. Wallet posts proof directly to verifier's callback endpoint
9. Wallet displays verification result

==== Schema

*Credential Storage Schema (IndexedDB):*

```json
{
  "credential": {
    "@context": ["https://www.w3.org/2018/credentials/v1"],
    "type": ["VerifiableCredential", "StudentCredential"],
    "issuer": "did:web:api.zeroverify.com",
    "issuanceDate": "2025-03-06T10:23:45Z",
    "expirationDate": "2026-03-06T10:23:45Z",
    "credentialSubject": {
      "id": "did:key:z6MkF5rGMoatr...",
      "enrollment_status": "student",
      "university": "Oakland University"
    },
    "credentialStatus": {
      "id": "https://s3.amazonaws.com/zeroverify-metadata/bitstring/v1/bitstring.gz#94567",
      "type": "BitstringStatusListEntry",
      "statusListIndex": "94567",
      "statusListCredential": "https://s3.amazonaws.com/zeroverify-metadata/bitstring/v1/bitstring.gz"
    },
    "proof": {
      "type": "Ed25519Signature2020",
      "created": "2025-03-06T10:23:45Z",
      "proofPurpose": "assertionMethod",
      "verificationMethod": "did:web:api.zeroverify.com#babyjubjub-key-1",
      "proofValue": "base64_babyjubjub_signature"
    }
  },
  "encrypted": true,
  "stored_at": "2025-03-06T10:23:45Z"
}
```

==== API Specs --- Function Prototypes

*Function: initiateIssuance()*

- *Name:* initiateIssuance
- *Location:* src/api/issuance.ts
- *Input(s):* None (user clicks button)
- *Output: Success:* Browser redirect to Keycloak OAuth endpoint with PKCE code challenge
- *Output: Error:* None (client-side redirect, no failure mode)
- *Description:* Generates PKCE verifier and challenge, stores verifier in localStorage, constructs OAuth authorization URL with required parameters, and redirects browser to Keycloak

*Function: handleOAuthCallback()*

- *Name:* handleOAuthCallback
- *Location:* src/api/issuance.ts
- *Input(s):* Authorization code from KeyCloak, PKCE code verifier from localStorage
- *Output: Success:* Credential object stored in IndexedDB, browser redirected to wallet view
- *Output: Error:*
  - 401 Unauthorized: "Authentication failed, please try again"
  - 409 Conflict: "You already have an active credential issued recently, please wait before requesting a new one"
  - 503 Service Unavailable: "University login service unavailable, try again later"
- *Note:* If an active credential exists but was issued more than 2 weeks ago, the Lambda automatically revokes the old credential and issues a new one (addresses lost credential scenario)
- *Description:* Extracts authorization code from URL, retrieves PKCE verifier from localStorage, calls POST /api/v1/credentials/issue, stores returned credential in IndexedDB encrypted, removes PKCE verifier from localStorage, redirects to wallet view

*Function: parseVerificationRequest()*

- *Name:* parseVerificationRequest
- *Location:* src/lib/proof.ts
- *Input(s):* URL query parameters (proof_type, verifier_id, challenge, callback)
- *Output: Success:* VerificationRequest object with parsed fields
- *Output: Error:* None (returns null if required parameters missing)
- *Description:* Parses URL query parameters into structured VerificationRequest object for display on consent screen

*Function: generateProof(request: VerificationRequest)*

- *Name:* generateProof
- *Location:* src/lib/proof.ts
- *Input(s):* VerificationRequest object, credential from IndexedDB
- *Output: Success:* zk-SNARK proof object containing proof_type, proof bytes, and public_inputs
- *Output: Error:*
  - "No credential found in wallet" (no credential in IndexedDB)
  - "Failed to load verification circuit, check internet connection" (circuit fetch from S3 failed)
  - "Proof generation failed, your credential may not support this request" (snarkjs proof generation failed)
- *Description:* Loads credential from IndexedDB, fetches circuit proving key from S3, prepares witness inputs based on proof type, generates zk-SNARK proof using snarkjs groth16.fullProve, returns proof object with public inputs including challenge nonce
- *Performance Target:* \< 4 seconds on mid-range devices (iPhone 12, 4GB RAM)

*Function: submitProofToVerifier(proof: Proof, callbackUrl: string)*

- *Name:* submitProofToVerifier
- *Location:* src/lib/proof.ts
- *Input(s):* Proof object, Verifier callback URL
- *Output: Success:* HTTP 200 from verifier
- *Output: Error:*
  - "Verifier rejected proof: [statusText]" (non-200 response from verifier)
- *Description:* Posts proof object to verifier's callback endpoint over HTTPS with Content-Type application/json and X-ZeroVerify-Version header, returns verification result

==== Dependencies on Other Components

- *Issuance Lambda:* Wallet depends on Issuance Lambda to exchange OAuth authorization code for signed credential. If Lambda is unavailable, credential issuance fails but existing credentials remain usable.

- *AWS S3 (Circuit Storage):* Wallet depends on S3 to fetch circuit proving keys during proof generation. If S3 is unavailable, proof generation fails.

- *Keycloak:* Wallet depends on Keycloak OAuth endpoints for authentication flow. If Keycloak is unavailable, credential issuance fails but existing credentials remain usable.

- *Verifier Callback Endpoint:* Wallet posts proof to verifier-provided callback endpoint. If endpoint is unreachable or rejects proof, verification fails but wallet functionality is unaffected.

==== Trade-offs

*Browser Storage vs. Hardware Wallet:*

Browser-based credential storage using IndexedDB with Web Crypto API encryption is less secure than Apple's Secure Enclave or dedicated hardware wallets. However, browser storage enables cross-platform compatibility (Windows, Mac, Linux, Android, iOS) without requiring specialized hardware or native app distribution. The trade-off prioritizes accessibility over maximum security. Credentials never leave the device, so compromise requires device-level access rather than server breach.

*Client-Side Proof Generation vs. Server-Side:*

Generating proofs client-side using snarkjs in WebAssembly shifts computational cost to user devices (2-5 seconds on mid-range devices). Server-side proof generation would be faster but requires transmitting the raw credential to the server, defeating the privacy guarantee. The trade-off prioritizes zero data disclosure over performance. Proof generation time is still faster than document upload and manual review flows used by competitors.

=== Keycloak (Identity Broker)

==== Purpose

Keycloak acts as a SAML/OAuth-to-OIDC broker, normalizing heterogeneous institutional identity systems (Shibboleth IdPs using SAML 2.0) into a consistent OIDC claims set that ZeroVerify's issuance layer can consume. Keycloak eliminates the need for ZeroVerify to implement SAML directly or maintain IdP-specific integrations.

==== Requirements Supported

- User authenticates via trusted Identity Provider (IdP) using OAuth/OIDC
- System validates authentication and receives verified attributes from IdP
- Institutions require no modification to support ZeroVerify (Keycloak appears as standard SAML service provider)

==== Detailed Design

Keycloak is deployed as a standalone service with a realm configured for ZeroVerify. Each institutional IdP is registered as an identity provider within the realm using SAML 2.0 Identity Provider configuration. When a user initiates authentication, Keycloak redirects to the institutional Shibboleth IdP via SAML redirect binding. After authentication, the IdP returns a SAML assertion to Keycloak. Keycloak extracts attributes from the assertion, maps them to standardized OIDC claims, and issues an authorization code to the browser wallet. The wallet exchanges this code for an OIDC token via Keycloak's token endpoint.

Keycloak normalizes IdP-specific claim names to consistent OIDC format:

- eduPersonPrincipalName #sym.arrow sub
- givenName #sym.arrow given_name
- sn #sym.arrow family_name
- mail #sym.arrow email
- eduPersonAffiliation #sym.arrow custom_claims.enrollment_status

==== Visual Workflow / Diagram

*Authentication Flow:*

1. User clicks "Verify with Oakland University" in browser wallet
2. Wallet redirects to Keycloak with IdP hint parameter: https://keycloak.zeroverify.com/realms/zeroverify/protocol/openid-connect/auth?kc_idp_hint=oakland.edu
3. Keycloak identifies IdP from kc_idp_hint parameter
4. Keycloak redirects to University IdP: https://shibboleth.oakland.edu/idp/profile/SAML2/Redirect/SSO
5. User authenticates with university credentials
6. IdP returns SAML assertion to Keycloak
7. Keycloak maps SAML attributes to OIDC claims
8. Keycloak issues authorization code
9. Wallet receives code and calls Issuance Lambda

==== Schema

*SAML Attribute Mapping Configuration:*

```json
{
  "idp_identifier": "oakland.edu",
  "saml_endpoint": "https://shibboleth.oakland.edu/idp/profile/SAML2/Redirect/SSO",
  "attribute_mapping": {
    "eduPersonPrincipalName": "sub",
    "givenName": "given_name",
    "sn": "family_name",
    "mail": "email",
    "eduPersonAffiliation": "custom_claims.enrollment_status"
  },
  "required_attributes": [
    "eduPersonPrincipalName",
    "eduPersonAffiliation"
  ]
}
```

*OIDC Token Response:*

```json
{
  "sub": "hashed_edu_person_principal_name",
  "email": "user@oakland.edu",
  "given_name": "Anton",
  "family_name": "Sakhanovych",
  "custom_claims": {
    "enrollment_status": "student",
    "university": "Oakland University"
  }
}
```

==== API Specs --- Function Prototypes

Keycloak is an external component with standard OIDC endpoints. ZeroVerify integrates via:

*Endpoint: GET /realms/zeroverify/protocol/openid-connect/auth*

- *Name:* Authorization Endpoint
- *Input(s):*
  - client_id: "zeroverify-wallet"
  - redirect_uri: "https://wallet.zeroverify.com/callback"
  - response_type: "code"
  - scope: "openid profile email"
  - code_challenge: PKCE challenge
  - code_challenge_method: "S256"
  - kc_idp_hint: IdP identifier (e.g., "oakland.edu") to skip IdP selection screen
- *Output: Success:* HTTP 302 redirect to redirect_uri with authorization code
- *Output: Error:*
  - 400 Bad Request: Invalid client_id or redirect_uri
  - 503 Service Unavailable: IdP unreachable

*Endpoint: POST /realms/zeroverify/protocol/openid-connect/token*

- *Name:* Token Endpoint
- *Input(s):*
  - grant_type: "authorization_code"
  - code: authorization code from auth endpoint
  - redirect_uri: must match authorization request
  - client_id: "zeroverify-wallet"
  - code_verifier: PKCE verifier
- *Output: Success:* OIDC token JSON with normalized claims
- *Output: Error:*
  - 400 Bad Request: Invalid or expired code
  - 401 Unauthorized: Invalid code_verifier

==== Dependencies on Other Components

- *University Shibboleth IdP:* Keycloak depends on institutional IdPs to complete SAML authentication flow. If IdP is unavailable, authentication fails and Keycloak returns HTTP 503 to browser wallet.

- *Issuance Lambda:* Issuance Lambda depends on Keycloak's token endpoint to exchange authorization code for OIDC claims. If Keycloak is unavailable, credential issuance fails.

==== Trade-offs

*Keycloak Broker vs. Direct SAML Integration:*

Using Keycloak as an identity broker adds an additional hop in the authentication flow (browser #sym.arrow Keycloak #sym.arrow IdP #sym.arrow Keycloak #sym.arrow wallet) compared to direct SAML integration. This increases latency by approximately 200-300ms. However, Keycloak eliminates the need for ZeroVerify to implement SAML parsing, XML signature validation, and IdP-specific attribute mapping logic. Adding a new institution requires only Keycloak realm configuration rather than code changes. The trade-off prioritizes maintainability and scalability over minimal latency.

*Centralized Keycloak vs. Distributed Brokers:*

Running a single Keycloak instance creates a single point of failure. If Keycloak is unavailable, all credential issuance fails regardless of IdP availability. Deploying distributed Keycloak instances with session replication would improve availability but increases infrastructure complexity and cost. For MVP, a single Keycloak instance with automatic restart is sufficient. Multi-region Keycloak deployment is deferred to post-MVP.

=== Issuance Lambda (AWS Lambda, Go)

==== Purpose

The Issuance Lambda is responsible for exchanging OAuth authorization codes with Keycloak for OIDC claims, checking for duplicate credential issuance, claiming free bit indices from Bitstring Index table, generating Baby Jubjub EdDSA signed verifiable credentials with individual field signatures, storing credential metadata in DynamoDB with TTL configuration, and returning signed credentials to the browser wallet.

==== Requirements Supported

- System validates authentication and receives verified attributes from IdP
- System creates signed credential using verified attributes
- Signed credential is delivered to user's wallet
- Do not persist raw identity attributes (persist only non-reversible cryptographic derivative of subject identifier to prevent duplicate credential issuance)
- System limits number of issued credentials

==== Detailed Design

The Lambda is implemented in Go for fast development velocity, excellent cryptographic library support, and predictable performance. The function is triggered by HTTP POST requests to API Gateway endpoint /api/v1/credentials/issue.

The Lambda execution flow:

1. Extract authorization code and code_verifier from request body
2. Call Keycloak token endpoint to exchange code for OIDC claims
3. Compute pseudonymous subject identifier: HMAC-SHA256(issuer_id || sub_id) using key from AWS Secrets Manager
4. Query DynamoDB Credential Metadata table with partition key = subject_id to check for existing active credentials
5. If active credentials exist (status = ACTIVE and expires_at > now):
   a. Check if issued_at is within 2 weeks (configurable threshold)
   b. If within threshold: return HTTP 409 Conflict
   c. If beyond threshold: proceed to step 6
6. Retrieve private key from AWS Secrets Manager (cached in memory for execution environment lifetime)
7. Claim free bit index from Bitstring Index table:
   a. Scan Bitstring Index for status=FREE bits (random offset selection)
   b. Attempt conditional write to claim bit (status=FREE #sym.arrow CLAIMED with version check)
   c. Retry up to 5 times on collision
   d. If all retries exhausted: append new bit index to table
8. Construct W3C Verifiable Credential JSON-LD document with claims from OIDC token
9. Generate Baby Jubjub EdDSA signature for each credential field using private key
10. Insert credential metadata into DynamoDB Credential Metadata table:
    - subject_id, credential_id, revocation_index (claimed bit_index)
    - status=ACTIVE, issued_at, expires_at
    - ttl = expires_at (triggers Free Lambda on expiry)
11. Bitstring Index DDB Stream triggers Bitstring Updater Lambda (sets S3 bit from 1 #sym.arrow 0)
12. Return signed credential to wallet as HTTP 201 Created response

==== Visual Workflow / Diagram

*Issuance Lambda Execution Flow:*

```
[Browser Wallet]
    |
    | POST /api/v1/credentials/issue
    | Body: { authorization_code, code_verifier }
    v
[API Gateway]
    |
    v
[Issuance Lambda]
    |
    | 1. Exchange code with Keycloak
    v
[Keycloak Token Endpoint]
    |
    | Returns OIDC claims
    v
[Issuance Lambda]
    |
    | 2. Compute HMAC(issuer || sub)
    | 3. Query DynamoDB for existing credential
    v
[DynamoDB - Credentials Table]
    |
    | Returns existing records (if any)
    v
[Issuance Lambda]
    |
    | 4. Check for active credentials
    |   a. Check if any were issued in the last 2 weeks
    |   b. If yes, return 409 Conflict, if not proceed
    | 5. Fetch key from Secrets Manager
    v
[AWS Secrets Manager]
    |
    | Returns private key
    v
[Issuance Lambda]
    |
    | 6. Claim free bit index (random selection + conditional write)
    | 7. Sign credential with Baby Jubjub EdDSA
    | 8. Insert metadata into DynamoDB (with ttl = expires_at)
    v
[DynamoDB - Credential Metadata Table]
    |
    v
[Issuance Lambda]
    |
    | 9. Return signed credential
    v
[Browser Wallet]
```

==== Schema

*DynamoDB Credentials Table Schema:*

```
Table Name: credentials

Partition Key: subject_id (String)
Sort Key: credential_id (String - UUID v4)

Attributes:
- subject_id: String (pseudonymous identifier, HMAC of issuer_id || idp_sub_id)
- credential_id: String (UUID v4)
- credential_type: String (Enum: StudentCredential, EmploymentCredential, AgeCredential)
- issued_at: String (ISO 8601 timestamp)
- expires_at: String (ISO 8601 timestamp)
- revocation_index: Number (bit position in W3C Status List bitstring)
- status: String (Enum: ACTIVE, REVOKED)

Data Integrity Rules:
- One subject_id can have multiple credential_id records (1:N relationship)
- Each credential_id must have unique revocation_index
- status transitions: ACTIVE -> REVOKED (irreversible)
- expires_at must be > issued_at
- DynamoDB TTL on REVOKED records: 90 days after expiration
```

==== API Specs --- Function Prototypes

*Function: exchange_oauth_token(code: String, verifier: String)*

- *Name:* exchange_oauth_token
- *Location:* src/domain/keycloak_manager.go
- *Input(s):*
  - code: String (authorization code from Keycloak)
  - verifier: String (PKCE code verifier)
- *Output: Success:* OIDCToken struct containing normalized claims (sub, email, given_name, family_name, custom_claims)
- *Output: Error:*
  - InvalidAuthorizationCode: code is invalid or expired (HTTP 400 from Keycloak)
  - IdpUnavailable: Keycloak unreachable (HTTP 503)
  - CircuitOpen: Circuit breaker triggered after 5 consecutive failures
- *Description:* Posts token exchange request to Keycloak endpoint with grant_type=authorization_code, parses JSON response, validates required claims presence, returns OIDCToken struct

*Function: compute_subject_id(issuer: String, sub: String)*

- *Name:* compute_subject_id
- *Location:* src/domain/crypto.go
- *Input(s):*
  - issuer: String (IdP identifier, e.g., oakland.edu)
  - sub: String (subject identifier from OIDC claims)
- *Output: Success:* String (base64-encoded HMAC-SHA256 hash)
- *Output: Error:* None (pure function, no failure mode)
- *Description:* Concatenates issuer || sub with delimiter, computes HMAC-SHA256 using key from Secrets Manager cache, returns base64-encoded hash as pseudonymous identifier

*Function: check_existing_credential(subject_id: String)*

- *Name:* check_existing_credential
- *Location:* src/domain/credential_metadata_manager.go
- *Input(s):*
  - subject_id: String (partition key)
- *Output: Success:* boolean (false if no active credential exists or true if exists a credential within re-issuance threshold)
- *Output: Error:*
  - Error: DynamoDB query failed
- *Description:* Queries DynamoDB Credentials table with partition key = subject_id, filters records where status = ACTIVE and expires_at > current_time. If found, checks if any record has an issued_at attribute within 2-week threshold. Returns boolean true only if within threshold (blocking issuance), otherwise returns false (allowing issuance)

*Function: sign_credential(credential: Credential, private_key: PrivateKey)*

- *Name:* sign_credential
- *Location:* src/domain/crypto.go
- *Input(s):*
  - credential: Credential struct (W3C Verifiable Credential document)
  - private_key: PrivateKey (private key from Secrets Manager)
- *Output: Success:* SignedCredential struct with signatures in proof field
- *Output: Error:*
  - SignatureGenerationFailed: Crypto library error
- *Description:* Serializes credential to canonical JSON-LD representation, computes signature over canonical bytes using private key, constructs proof object with signature and metadata, returns SignedCredential
- *Performance Target:* 6-7.5ms per signature

*Function: claim_free_bit_index(credential_id: String, max_retries: int)*

- *Name:* claim_free_bit_index
- *Location:* src/domain/bit_index_manager.go
- *Input(s):*
  - credential_id: String (UUID v4 of credential being issued)
  - max_retries: int (default 5, configurable retry threshold)
- *Output: Success:* u64 (claimed bit index)
- *Output: Error:*
  - Error: DynamoDB query failed
  - Error: Max retries exhausted, all free bits claimed (triggers bitstring expansion)
- *Description:* Scans DynamoDB bit_indices table for records with status=FREE, selects random index from result set, attempts conditional write to set status=CLAIMED with version check. On collision (ConditionalCheckFailedException), retries with different random selection. After max_retries exhausted, appends new bit index to table and claims it.

*Function: insert_credential_metadata(record: CredentialRecord)*

- *Name:* insert_credential_metadata
- *Location:* src/domain/credential_metadata_manager.go
- *Input(s):*
  - record: CredentialRecord struct (credential metadata)
- *Output: Success:* Unit type () indicating successful write
- *Output: Error:*
  - Error: DynamoDbError: Insert operation failed
- *Description:* Writes CredentialRecord to DynamoDB Credentials table with subject_id as partition key and credential_id as sort key

==== Dependencies on Other Components

- *Keycloak Token Endpoint:* Issuance Lambda depends on Keycloak to exchange authorization code for OIDC claims. If Keycloak is unavailable, Lambda returns HTTP 503 to wallet.

- *AWS Secrets Manager:* Lambda depends on Secrets Manager to retrieve Baby Jubjub EdDSA private key and HMAC key. Keys are cached in memory for execution environment lifetime (15 minutes). If Secrets Manager is unavailable during cold start, Lambda returns HTTP 503.

- *DynamoDB Credentials Table:* Lambda depends on DynamoDB for duplicate credential checks and metadata storage. If DynamoDB is unavailable, Lambda returns HTTP 503.

- *API Gateway:* Lambda is invoked via API Gateway HTTP integration. If API Gateway is unavailable, requests do not reach Lambda.

==== Trade-offs

*Go vs. Node.js/Python:*

Implementing the Lambda in Go instead of Node.js or Python provides a balance between development velocity and performance. Go Lambda cold starts average 150-400ms versus Node.js 400-800ms and Python 500-1000ms. For credential issuance in an OAuth callback flow, cold start latency directly impacts user experience. Go has mature cryptographic libraries for Baby Jubjub EdDSA operations and excellent concurrency support without garbage collection pauses during signature operations. The trade-off prioritizes development velocity and ecosystem support over minimal cold start times.

*Lambda vs. EC2/ECS:*

Using Lambda instead of persistent compute (EC2 or ECS) introduces cold start latency (100-300ms) but eliminates idle costs and operational overhead. Credential issuance traffic is unpredictable with spikes during university enrollment periods (August-September). Lambda's automatic scaling handles spikes without manual intervention or over-provisioning. The trade-off prioritizes cost efficiency and operational simplicity over eliminating cold starts. Reserved concurrency can keep warm execution environments during peak periods if cold starts become problematic.

*Duplicate Check vs. Idempotency:*

Checking for existing active credentials before issuance prevents users from accumulating many credentials from the same IdP. Credential lifetime of 1 month and the 2 week cooldown allows users to get multiple credentials for the same IdP. However, this introduces a race condition: two concurrent issuance requests for the same subject_id could both pass the duplicate check and issue two credentials. The system does not implement distributed locking or idempotency tokens for MVP. The likelihood of concurrent issuance for the same user is low, and the impact is limited (user has two credentials, both valid). The trade-off accepts low-probability duplicate issuance to avoid distributed locking complexity.

=== DynamoDB

==== Purpose

DynamoDB stores credential metadata (issuance records, revocation indices, expiration timestamps) to support duplicate credential checks during issuance and revocation status updates. DynamoDB does not store raw personal identity attributes.

==== Requirements Supported

- Do not persist raw identity attributes (persist only non-reversible cryptographic derivative of subject identifier)
- Users can hold limited amount of active credential per identity provider at a time
- System checks credential revocation status during verification
- Track bit index allocation with optimistic locking to prevent race conditions during concurrent issuance

==== Detailed Design

DynamoDB is chosen over RDS PostgreSQL because the access pattern is pure key-value lookups. Credential issuance queries by subject_id (partition key). Bit index allocation uses conditional writes on bit_indices table with optimistic locking. No joins, no complex transactions, no relational integrity constraints beyond what DynamoDB provides. DynamoDB's single-digit millisecond latency (p99 \< 20ms) meets the credential issuance budget.

DynamoDB Global Tables provide multi-region replication (us-east-1, us-west-2). All writes are routed to the IAD region (us-east-1) to prevent consistency issues during concurrent updates. Reads can occur from any region using eventual consistency.

*DynamoDB Streams Integration:*

The bit_indices table has DynamoDB Streams enabled with NEW_AND_OLD_IMAGES stream view type. When a bit index transitions from FREE to CLAIMED (credential issuance) or CLAIMED to FREE (credential expiry/revocation), a stream record is generated. A Lambda function consumes the stream, batches updates (up to 100 records), and periodically updates the W3C Bitstring Status List in S3. This decouples real-time bit allocation (fast, optimistic locking) from bitstring publishing (batched, eventual consistency). The stream-based architecture ensures all bit status changes are eventually reflected in S3 without blocking credential issuance on S3 uploads.

==== Schema

*Credentials Table:*

```
Table Name: credentials
Partition Key: subject_id (String)
Sort Key: credential_id (String)
Billing Mode: On-Demand
Global Secondary Indexes: None
TTL Attribute: ttl (Number, UNIX timestamp)
DynamoDB Streams: Enabled (NEW_AND_OLD_IMAGES)

Attributes:
- subject_id: Pseudonymous user identifier (HMAC-SHA256 of issuer_id || idp_sub_id)
- credential_id: UUID v4
- credential_type: Enum string (Student_Credential, Employment_Credential, Age_Credential)
- issued_at: ISO 8601 timestamp
- expires_at: ISO 8601 timestamp
- revocation_index: Number (bit position in W3C Status List bitstring, range 0 to 2^32)
- status: Enum string (ACTIVE, REVOKED)
- ttl: UNIX timestamp (set to expires_at, triggers DDB TTL event for Free Lambda)

Data Integrity Rules:
- One subject_id can have multiple credential_id records (1:N)
- Each credential_id is globally unique (UUID v4)
- Each revocation_index is globally unique (allocated from Bitstring Index with conditional writes)
- status transitions: ACTIVE -> REVOKED (triggered by explicit revocation)
- expires_at > issued_at (validated by Lambda before insert)

DynamoDB Streams Configuration:
- Stream View Type: NEW_AND_OLD_IMAGES
- Stream triggers: Free Lambda (when status changes to REVOKED for explicit revocation)

TTL Configuration:
- TTL Attribute: ttl
- TTL fires within 48 hours of timestamp
- Triggers: Free Lambda via DDB TTL event (for automatic expiry, both ACTIVE and REVOKED credentials)

Note: Free Lambda has TWO triggers from this table:
1. DDB Streams (explicit revocation, real-time ~100-500ms)
2. DDB TTL (automatic expiry, within 48 hours of ttl timestamp)
```

*Bit Index Table:*

```
Table Name: bit_indices
Partition Key: bit_index (Number)
Billing Mode: On-Demand
DynamoDB Streams: Enabled (NEW_AND_OLD_IMAGES)

Attributes:
- bit_index: Number (bit position in W3C Status List bitstring, range 0 to 2^32)
- status: String (Enum: FREE, CLAIMED, REVOKED)
- credential_id: String (UUID v4, present when status=CLAIMED or REVOKED)
- claimed_at: String (ISO 8601 timestamp, present when status=CLAIMED or REVOKED)
- version: Number (incremented atomically for optimistic locking)

Data Integrity Rules:
- Each bit_index is globally unique (partition key)
- status transitions:
  - FREE -> CLAIMED (credential issuance)
  - CLAIMED -> REVOKED (explicit revocation)
  - CLAIMED -> FREE (TTL expiry, never revoked)
  - REVOKED -> FREE (TTL expiry after revocation)
- credential_id must be present when status=CLAIMED or REVOKED
- Conditional writes enforce version-based optimistic locking to prevent race conditions

Bitstring Mapping (for S3 W3C Bitstring Status List):
- status=CLAIMED -> bitstring bit = 0 (credential active)
- status=REVOKED -> bitstring bit = 1 (credential revoked)
- status=FREE -> bitstring bit = 1 (bit can be reused)
```

==== API Specs --- Function Prototypes

DynamoDB is accessed via AWS SDK. Key operations:

*Operation: Query credentials by subject_id*

- *Name:* query_by_subject_id
- *Input(s):*
  - subject_id: String (partition key)
  - filter: status = ACTIVE AND expires_at > current_time
- *Output: Success:* List of CredentialRecord structs matching filter
- *Output: Error:* DynamoDB service error (throttling, unavailable)
- *Performance:* p99 \< 20ms

*Operation: Insert credential metadata*

- *Name:* put_item
- *Input(s):*
  - record: CredentialRecord struct
- *Output: Success:* Unit type ()
- *Output: Error:* DynamoDB service error
- *Performance:* p99 \< 20ms

*Operation: Conditional write to claim bit index*

- *Name:* conditional_update_bit_index
- *Input(s):*
  - bit_index: Number (randomly selected free bit)
  - expected_status: "FREE"
  - new_status: "CLAIMED"
  - credential_id: String (UUID v4)
- *Output: Success:* Unit type () (bit successfully claimed)
- *Output: Error:*
  - ConditionalCheckFailedException (bit already claimed, retry with different index)
  - DynamoDB service error
- *Performance:* p99 \< 20ms

*Operation: Update credential status to REVOKED*

- *Name:* update_item_status
- *Input(s):*
  - subject_id: String (partition key)
  - credential_id: String (sort key)
  - new_status: "REVOKED"
- *Output: Success:* Unit type ()
- *Output: Error:* DynamoDB service error or conditional check failed
- *Performance:* p99 \< 20ms

==== Dependencies on Other Components

- *Issuance Lambda:* Depends on DynamoDB for duplicate credential checks, bit index claiming (Bitstring Index table), and metadata insertion (Credential Metadata table). If DynamoDB is unavailable, issuance fails.

- *Revocation Processor Lambda:* Depends on DynamoDB to update credential status to REVOKED in Credential Metadata table. If DynamoDB is unavailable, revocation processing stalls.

- *Free Lambda:* Depends on DynamoDB to update Bitstring Index table (set status to REVOKED or FREE). If DynamoDB is unavailable, bit freeing stalls.

- *Bitstring Updater Lambda:* Triggered by DDB Streams on Bitstring Index table. Reads stream events to update S3 bitstring.

- *Verification Library (External):* Verifiers do not query DynamoDB directly. Revocation status is checked via W3C Bitstring Status List stored in S3, which is updated by Bitstring Updater Lambda based on Bitstring Index DDB Stream events.

==== Trade-offs

*DynamoDB vs. RDS PostgreSQL:*

DynamoDB is chosen over RDS PostgreSQL because the access pattern is pure key-value lookups with no complex joins or transactions. DynamoDB's single-digit millisecond latency (p99 \< 20ms) meets credential issuance performance requirements. PostgreSQL would require connection pooling, schema migrations, and manual scaling. DynamoDB Global Tables provide automatic multi-region replication with eventual consistency, whereas PostgreSQL multi-region replication requires third-party tools or AWS Aurora Global Database. The trade-off accepts eventual consistency and schemaless data model in exchange for operational simplicity and performance. The lack of foreign key constraints is acceptable because data integrity is enforced at the application layer (Lambda validation).

*On-Demand vs. Provisioned Capacity:*

DynamoDB tables use On-Demand billing mode instead of Provisioned Capacity. On-Demand automatically scales to handle traffic spikes without capacity planning but costs approximately 25% more per request at steady-state load. For MVP with unpredictable traffic patterns (university enrollment spikes), On-Demand eliminates the risk of throttling and operational overhead of capacity planning. The trade-off prioritizes operational simplicity over cost optimization. Provisioned Capacity with auto-scaling can be evaluated post-MVP once traffic patterns are established.

*Global Tables vs. Single Region:*

Using DynamoDB Global Tables for multi-region replication introduces eventual consistency (typically \< 1 second replication lag). A credential issued in us-east-1 may not be immediately queryable from us-west-2. To mitigate this, all writes (issuance, revocation) are routed to a single region (us-east-1), while reads can occur from any region. For credential issuance duplicate checks, the Lambda queries the local region, accepting the risk of duplicate issuance during replication lag (low probability, low impact). The trade-off prioritizes global read availability over strong consistency.

=== AWS S3 (Revocation Bitstring Storage & Circuit Storage)

==== Purpose

S3 serves two purposes: (1) storing the W3C Bitstring Status List for credential revocation checks, and (2) hosting circuit proving keys, verification keys, and WebAssembly files for client-side proof generation. Both use cases require globally accessible static objects with high availability.

==== Requirements Supported

- System checks credential revocation status during verification
- User generates zero-knowledge proof using circuit proving keys fetched from S3
- Verifiers can download revocation bitstring without authentication (public endpoint)
- Verifiers can fetch a verification key for the circuit

==== Detailed Design

*Revocation Bitstring:*

The W3C Bitstring Status List is stored as a GZIP-compressed object in S3 bucket `zeroverify-metadata`. For 10,000 credentials, the bitstring is ~1.25KB compressed. Verifiers download the bitstring via public HTTPS GET and check revocation status locally by inspecting the bit at position revocation_index. S3 Cross-Region Replication (CRR) ensures global availability across us-east-1, us-east-2, us-west-2.

*Circuit Storage:*

Circom circuit artifacts (proving keys .zkey files, WebAssembly .wasm files, verification keys verification_key.json) are stored in S3 bucket `zeroverify-metadata` organized by proof type. Browser wallet fetches these files during proof generation. Objects are served with Cache-Control headers (max-age=86400, 24 hours) to enable client-side caching.

==== Schema

*Revocation Bitstring Object:*

```
Bucket: zeroverify-metadata
Object Key: bitstring/v1/bitstring.gz
Format: GZIP-compressed W3C Bitstring Status List (base64-encoded bitstring)
Size: ~1.25KB compressed for 10,000 credentials
Content-Type: application/gzip
Cache-Control: public, max-age=300 (5-minute cache)
Public Access: Enabled (verifiers fetch without authentication)

Bitstring Structure:
- Base64-encoded binary string (1 bit per credential)
- Bit position corresponds to bit_index in Bitstring Index DDB table
- Bit value: 0 = ACTIVE, 1 = REVOKED or FREE
- Note: Bitstring Index table has 3 states (CLAIMED/REVOKED/FREE) but S3 bitstring only shows 2 values (0/1)
```

*Circuit Artifacts:*

```
Bucket: zeroverify-metadata
Object Key Structure: circuit/{proof_type}/proving_key.zkey
                      circuit/{proof_type}/circuit.wasm
                      circuit/{proof_type}/verification_key.json
Example Keys:
  - circuit/student_status/proving_key.zkey (Groth16 proving key for student status circuit)
  - circuit/student_status/circuit.wasm (Circuit witness computation WebAssembly)
  - circuit/student_status/verification_key.json (Groth16 verification key)
  - circuit/age_over_21/proving_key.zkey
  - circuit/age_over_21/circuit.wasm
  - circuit/age_over_21/verification_key.json

Content-Type: application/octet-stream
Cache-Control: public, max-age=86400 (24-hour cache)
Public Access: Enabled
```

==== API Specs --- Function Prototypes

S3 is accessed via standard HTTP GET requests (public objects) and AWS SDK (Lambda writes).

*Operation: Download Revocation Bitstring (Verifier)*

- *Name:* GET https://s3.amazonaws.com/zeroverify-metadata/bitstring/v1/bitstring.gz
- *Input(s):* None (public endpoint)
- *Output: Success:* GZIP-compressed bitstring bytes, HTTP 200
- *Output: Error:*
  - 404 Not Found: Object does not exist
  - 403 Forbidden: Bucket policy misconfigured
  - 503 Service Unavailable: S3 service degradation
- *Description:* Verifier downloads bitstring, decompresses using gzip, decodes base64, checks bit at revocation_index position

*Operation: Fetch Circuit Proving Key (Browser Wallet)*

- *Name:* GET https://s3.amazonaws.com/zeroverify-metadata/circuit/{proof_type}/proving_key.zkey
- *Input(s):* proof_type (student_status, age_over_21, etc.)
- *Output: Success:* Proving key file, HTTP 200
- *Output: Error:*
  - 404 Not Found: Proof type not supported
  - 403 Forbidden: Bucket policy misconfigured
- *Description:* Wallet fetches proving key required for zk-SNARK proof generation using snarkjs

*Operation: Fetch Circuit (Browser Wallet)*

- *Name:* GET https://s3.amazonaws.com/zeroverify-metadata/circuit/{proof_type}/circuit.wasm
- *Input(s):* proof_type (student_status, age_over_21, etc.)
- *Output: Success:* Circuit implementation wasm file, HTTP 200
- *Output: Error:*
  - 404 Not Found: Proof type not supported
  - 403 Forbidden: Bucket policy misconfigured
- *Description:* Wallet fetches circuit implementation required for zk-SNARK proof generation using snarkjs

*Operation: Fetch Verification Key (Verifier)*

- *Name:* GET https://s3.amazonaws.com/zeroverify-metadata/circuit/{proof_type}/verification_key.json
- *Input(s):* proof_type (student_status, age_over_21, etc.)
- *Output: Success:* Verification key json file, HTTP 200
- *Output: Error:*
  - 404 Not Found: Proof type not supported
  - 403 Forbidden: Bucket policy misconfigured
- *Description:* Verifier fetches verification key required for zk-SNARK proof verification

*Operation: Update Revocation Bitstring (Bitstring Updater Lambda)*

- *Name:* s3_put_object
- *Input(s):*
  - bucket: "zeroverify-metadata"
  - key: "bitstring/v1/bitstring.gz"
  - body: GZIP-compressed updated bitstring bytes
- *Output: Success:* ETag of uploaded object
- *Output: Error:* S3 service error (throttling, unavailable)
- *Performance:* p99 \< 1 second for 1.25KB object

==== Dependencies on Other Components

- *Bitstring Updater Lambda:* Depends on S3 to download current bitstring, update bits according to Bitstring Index changes, and upload updated bitstring. If S3 is unavailable, bitstring updates stall.

- *Browser Wallet:* Depends on S3 to fetch circuit proving keys during proof generation. If S3 is unavailable, proof generation fails but existing credentials remain usable.

- *Verifiers:* Depend on S3 to download revocation bitstring and verification key during verification. If S3 is unavailable, verification fails-safe (proof is rejected rather than approved without revocation check).

==== Trade-offs

*S3 vs. DynamoDB for Bitstring:*

Storing the revocation bitstring in S3 as a static object instead of DynamoDB is chosen for two reasons: (1) verifiers can fetch the bitstring via unauthenticated HTTP GET without AWS credentials, and (2) S3 is optimized for serving static objects globally with low latency. DynamoDB would require verifiers to authenticate with AWS credentials or use an API Gateway proxy, adding complexity. The trade-off accepts eventual consistency during bitstring updates (S3 Cross-Region Replication takes \<15 minutes) in exchange for verifier simplicity.

*Public S3 Bucket vs. CloudFront CDN:*

The revocation bitstring is served directly from S3 public endpoints instead of CloudFront CDN. For a 1.25KB object, S3 transfer costs are negligible (\<\$0.01 per 1000 requests), and verifiers are expected to cache the bitstring locally for 5 minutes (Cache-Control header). CloudFront would add operational complexity (cache invalidation, distribution configuration) without meaningful performance benefit for this use case. The trade-off prioritizes simplicity over micro-optimization. If verifier traffic scales to millions of requests per day, CloudFront can be added without architectural changes.

*W3C Bitstring Status List vs. OCSP:*

Using W3C Bitstring Status Lists instead of OCSP (Online Certificate Status Protocol) is chosen for privacy. OCSP requires querying a server with the credential ID, revealing which credential is being verified and creating a centralized tracking point. Bitstrings allow verifiers to download a compact list and check revocation status locally without revealing which credential they are verifying. The trade-off accepts slightly larger downloads (1.25KB for 10,000 credentials vs. single OCSP response) in exchange for verification privacy.

=== Revocation Processor Lambda (AWS Lambda, Go)

==== Purpose

The Revocation Processor Lambda processes explicit user revocation requests from the API Gateway. It validates zk-SNARK proofs of credential ownership and updates the Credential Metadata table to mark credentials as revoked.

==== Requirements Supported

- System supports credential revocation by authorized users
- Validate revocation proof (zk-SNARK proof of credential ownership)
- Update credential status to REVOKED
- Trigger Free Lambda via DDB Streams on Credential Metadata table

==== Detailed Design

The Revocation Processor Lambda is triggered by API Gateway.

*Processing Flow:*

1. Lambda receives request containing credential_id and revocation_proof
2. For each message, validate revocation proof (zk-SNARK proof of credential ownership)
3. Query Credential Metadata table to verify credential exists and is ACTIVE
4. Update Credential Metadata: set status=REVOKED
5. Credential Metadata DDB Stream event triggers Free Lambda
6. Free Lambda updates Bitstring Index: CLAIMED -> REVOKED

*Key Design Decision:*

Revocation Processor does NOT directly update Bitstring Index. It only updates Credential Metadata, which triggers Free Lambda via DDB Streams. This keeps responsibilities clean: Revocation Processor validates and records revocation, Free Lambda handles all bit state transitions.

*Error Handling:*

- Invalid proof: Skip message
- Credential not found: Skip message
- DDB write failure: automatic retry up to 3 times

==== Visual Workflow / Diagram

*Revocation Processing Flow:*

```
[User submits revocation request]
    |
    | POST /api/v1/credentials/revoke
    | Body: { credential_id, revocation_proof }
    v
[API Gateway]
    |
    | Calls
    v
[Revocation Processor Lambda]
    |
    | 1. Validate revocation proof (zk-SNARK)
    | 2. Query Credential Metadata table
    v
[DynamoDB - Credential Metadata Table]
    |
    | Returns credential record (if exists)
    v
[Revocation Processor Lambda]
    |
    | 3. Update Credential Metadata: status=REVOKED
    v
[DynamoDB - Credential Metadata Table]
    |
    | DDB Streams generates MODIFY event
    v
[Free Lambda]
    |
    | Update Bitstring Index: CLAIMED -> REVOKED
    v
[Bitstring Index Table]
    |
    | DDB Streams generates MODIFY event
    v
[Bitstring Updater Lambda]
    |
    | Download S3 bitstring, set bit=1, upload
    v
[S3 - Revocation Bitstring]
```

==== Schema

*Message Schema:*

```json
{
  "credential_id": "a3f8b2c1-4d5e-6f7a-8b9c-0d1e2f3a4b5c",
  "revocation_proof": {
    "proof_type": "credential_ownership",
    "proof": "base64_zk-SNARK_proof",
    "public_inputs": {
      "credential_id_hash": "keccak256(credential_id)",
      "timestamp": 1709722980
    }
  }
}
```

==== API Specs --- Function Prototypes

*Function: process_message(message: Message)*

- *Name:* process_revocation
- *Location:* src/handler.go
- *Input(s):*
  - message: message containing credential_id and revocation_proof
- *Output: Success:* nil
- *Output: Error:*
  - Error: DynamoDB query or update failed
  - Error: Invalid proof (message skipped)
- *Description:* Processes revocation request from API Gateway. Validates proof, queries Credential Metadata table, updates status to REVOKED.

*Function: validate_revocation_proof(credential_id: string, proof: RevocationProof)*

- *Name:* validate_revocation_proof
- *Location:* src/crypto.go
- *Input(s):*
  - credential_id: String (UUID v4)
  - proof: RevocationProof struct (zk-SNARK proof of credential ownership)
- *Output: Success:* bool (true if proof is valid)
- *Output: Error:* nil
- *Description:* Verifies zk-SNARK proof against verification key, checks public inputs match credential_id hash and timestamp is within acceptable range (#sym.plus 5 minutes)

*Function: update_credential_status(credential_id: string, status: string)*

- *Name:* update_credential_status
- *Location:* src/domain/credential_metadata_manager.go
- *Input(s):*
  - credential_id: String (UUID v4)
  - status: String ("REVOKED")
- *Output: Success:* nil
- *Output: Error:*
  - Error: DynamoDB update failed
  - Error: Credential not found
- *Description:* Updates Credential Metadata table, sets status field to REVOKED. Triggers DDB Stream event that Free Lambda consumes.

==== Dependencies on Other Components

- *DynamoDB Credential Metadata Table:* Lambda depends on DynamoDB to query and update credential status. If DynamoDB is unavailable, Lambda returns error and messages return to queue for retry.

- *Free Lambda:* Revocation Processor triggers Free Lambda indirectly via Credential Metadata DDB Streams. If Free Lambda is unavailable, Bitstring Index is not updated but stream records are retained.

==== Trade-offs

*SQS Queue vs. Direct Lambda Invocation:*

Direct Lambda invocation is chosen over SQS because revocation is an inherently low-throughput operation --- concurrency will never approach Lambda throttling thresholds, making SQS buffering unnecessary overhead with no reliability benefit at this scale.

*Indirect Bitstring Index Update vs. Direct Update:*

Revocation Processor updates only Credential Metadata, triggering Free Lambda via DDB Streams to update Bitstring Index. This separates concerns (validation vs. bit management) and keeps Free Lambda as the single source of truth for bit state transitions. Direct update would be faster (~100ms) but creates dual responsibility and potential inconsistencies. The trade-off prioritizes architectural clarity over minimal latency.

=== Free Lambda (AWS Lambda, Go)

==== Purpose

The Free Lambda handles bit freeing from BOTH explicit revocation (via DDB Streams on Credential Metadata) and automatic expiry (via DDB TTL). It updates the Bitstring Index table to transition bits from CLAIMED/REVOKED to FREE or from CLAIMED to REVOKED.

==== Requirements Supported

- Reclaim bit indices from revoked credentials (explicit user revocation)
- Reclaim bit indices from expired credentials (TTL automatic expiry)
- Maintain Bitstring Index as source of truth for bit status
- Trigger Bitstring Updater Lambda via Bitstring Index DDB Streams

==== Detailed Design

Free Lambda has TWO triggers:
1. DDB Streams on Credential Metadata table (when status changes to REVOKED)
2. DDB TTL events on Credential Metadata table (when ttl timestamp expires)

*Processing Flow:*

*Trigger 1: Credential Metadata DDB Stream (Explicit Revocation)*
1. Stream event: Credential Metadata status changed from ACTIVE #sym.arrow REVOKED
2. Extract credential_id and revocation_index from stream record
3. Update Bitstring Index: set status=REVOKED for that bit_index
4. Bitstring Index Stream event triggers Bitstring Updater Lambda
5. Bitstring Updater sets S3 bit from 0 #sym.arrow 1

*Trigger 2: DDB TTL Event (Automatic Expiry)*
1. TTL event: Credential Metadata ttl timestamp expired
2. Extract credential_id and revocation_index from TTL record
3. Query Bitstring Index to get current status (may be CLAIMED or REVOKED)
4. Update Bitstring Index: set status=FREE for that bit_index
5. Bitstring Index Stream event triggers Bitstring Updater Lambda (if status changed)
6. Bitstring Updater sets S3 bit (CLAIMED #sym.arrow FREE: 0 #sym.arrow 1, REVOKED #sym.arrow FREE: 1 #sym.arrow 1 skip update)

*State Transitions Handled:*
- CLAIMED #sym.arrow REVOKED (explicit revocation via Streams)
- CLAIMED #sym.arrow FREE (TTL expiry, never revoked)
- REVOKED #sym.arrow FREE (TTL expiry after revocation)

==== Visual Workflow / Diagram

*Flow 1: Explicit Revocation (via Streams):*

```
[Revocation Processor Lambda]
    |
    | Update Credential Metadata: status=REVOKED
    v
[Credential Metadata DDB Stream]
    |
    | MODIFY event: status ACTIVE -> REVOKED
    v
[Free Lambda]
    |
    | Extract revocation_index
    | Update Bitstring Index: CLAIMED -> REVOKED
    v
[Bitstring Index DDB Stream]
    |
    | MODIFY event triggers Bitstring Updater
    v
[Bitstring Updater Lambda]
    |
    | Set S3 bit: 0 -> 1
```

*Flow 2: TTL Expiry:*

```
[Credential Metadata TTL expires]
    |
    | DDB TTL event generated
    v
[Free Lambda]
    |
    | Extract revocation_index
    | Query Bitstring Index (current status: CLAIMED or REVOKED)
    | Update Bitstring Index: status -> FREE
    v
[Bitstring Index DDB Stream]
    |
    | MODIFY event triggers Bitstring Updater (if bit value changes)
    v
[Bitstring Updater Lambda]
    |
    | CLAIMED -> FREE: set bit 0 -> 1
    | REVOKED -> FREE: skip (already 1)
```

==== Schema

*Credential Metadata DDB Stream Record (Explicit Revocation):*

```json
{
  "eventName": "MODIFY",
  "dynamodb": {
    "NewImage": {
      "credential_id": { "S": "uuid" },
      "status": { "S": "REVOKED" },
      "revocation_index": { "N": "94567" }
    },
    "OldImage": {
      "status": { "S": "ACTIVE" }
    }
  }
}
```

*DDB TTL Event Record (Expiry):*

```json
{
  "Records": [{
    "eventName": "REMOVE",
    "userIdentity": {
      "type": "Service",
      "principalId": "dynamodb.amazonaws.com"
    },
    "dynamodb": {
      "OldImage": {
        "credential_id": { "S": "uuid" },
        "revocation_index": { "N": "94567" },
        "status": { "S": "REVOKED" },
        "ttl": { "N": "1709722980" }
      }
    }
  }]
}
```

==== API Specs --- Function Prototypes

*Function: handle_credential_event(record: DDBStreamRecord or DDBTTLRecord)*

- *Name:* handle_credential_event
- *Location:* src/free_lambda/handler.go:15
- *Input(s):*
  - record: Either DDB Stream record or TTL event record
- *Output: Success:* nil
- *Output: Error:*
  - Error: DynamoDB update failed (Bitstring Index)
- *Description:* Determines event type (Stream vs TTL), extracts revocation_index, updates Bitstring Index with appropriate status transition (CLAIMED #sym.arrow REVOKED for Streams, any #sym.arrow FREE for TTL)

*Function: free_bit_index(bit_index: u64, new_status: string)*

- *Name:* free_bit_index
- *Location:* src/free_lambda/db.go:45
- *Input(s):*
  - bit_index: Number (bit position)
  - new_status: String ("REVOKED" or "FREE")
- *Output: Success:* nil
- *Output: Error:*
  - Error: DynamoDB update failed
- *Description:* Updates Bitstring Index table, sets status field to new_status. Triggers DDB Stream event that Bitstring Updater Lambda consumes.

==== Dependencies on Other Components

- *Credential Metadata DDB Streams:* Lambda is triggered by Stream events when credentials are revoked. If Streams is unavailable, explicit revocations don't trigger bit updates but stream records are retained.

- *Credential Metadata DDB TTL:* Lambda is triggered by TTL events when credentials expire. TTL fires within 48 hours of expiry timestamp. If TTL service is unavailable, expiry processing is delayed.

- *Bitstring Index Table:* Lambda depends on DynamoDB to update bit status. If DynamoDB is unavailable, Lambda retries with exponential backoff.

- *Bitstring Updater Lambda:* Free Lambda triggers Bitstring Updater indirectly via Bitstring Index DDB Streams. If Bitstring Updater is unavailable, S3 bitstring is not updated but stream records are retained.

==== Trade-offs

*DDB TTL vs. Scheduled Batch Jobs:*

Using DDB TTL for automatic expiry instead of scheduled Lambda batch jobs simplifies architecture and reduces operational overhead. TTL is fully managed by AWS with no infrastructure to maintain. However, TTL fires within 48 hours of expiry (not real-time), which is acceptable since verifiers cache bitstrings for 5 minutes. Batch jobs would provide precise expiry timing but require scheduling, monitoring, and failure handling. The trade-off prioritizes operational simplicity over real-time expiry.

*DDB Streams vs. Polling for REVOKED Status:*

Using DDB Streams on Credential Metadata for explicit revocation instead of polling provides near-real-time updates (~100-500ms latency). Polling would require periodic Lambda invocations to scan for status changes, increasing cost and latency. Streams provide automatic triggering with guaranteed delivery. The trade-off prioritizes real-time updates and cost efficiency over polling simplicity.

*Single Lambda for Both Triggers vs. Separate Lambdas:*

Using one Lambda with two trigger types (Streams + TTL) instead of separate Lambdas reduces code duplication and operational complexity. Both flows update Bitstring Index, differing only in target status (REVOKED vs FREE). Separate Lambdas would provide clearer separation of concerns but increase deployment and monitoring overhead. The trade-off prioritizes code reuse and operational simplicity over strict separation.

=== Bitstring Updater Lambda (AWS Lambda, Go)

==== Purpose

The Bitstring Updater Lambda listens to DDB Streams on the Bitstring Index table, batches bit status changes, and updates the W3C Bitstring Status List in S3. It only updates S3 when bit values actually change (optimized to skip REVOKED #sym.arrow FREE transitions since both map to bit=1).

==== Requirements Supported

- Keep S3 bitstring synchronized with Bitstring Index table
- Handle concurrent updates with ETag-based locking
- Update on meaningful bit value changes (optimize for cost)
- Batch updates for throughput efficiency

==== Detailed Design

Bitstring Updater Lambda is triggered by DDB Streams on the Bitstring Index table. When bit status changes (CLAIMED/REVOKED/FREE transitions), stream records are generated and batched by Lambda Event Source Mapping (up to 100 records per invocation).

*Stream Processing Flow:*

1. Lambda receives batch of DDB Stream records from Bitstring Index table
2. For each record, extract bit_index and new status from NewImage
3. Filter records to only process bit value changes:
   - CLAIMED #sym.arrow REVOKED: Process (0 #sym.arrow 1)
   - CLAIMED #sym.arrow FREE: Process (0 #sym.arrow 1)
   - FREE #sym.arrow CLAIMED: Process (1 #sym.arrow 0)
   - REVOKED #sym.arrow FREE: Skip (1 #sym.arrow 1, no change)
4. Download current bitstring from S3 with ETag
5. Modify bits according to filtered records:
   - status=CLAIMED: set bit to 0
   - status=REVOKED or FREE: set bit to 1
6. Compress updated bitstring
7. Upload to S3 with If-Match: ETag (conditional write)
8. If ETag conflict: retry with fresh S3 download
9. If success: checkpoint stream position

*Concurrency Handling:*

Multiple Lambda invocations may process different batches concurrently. S3 ETag-based conditional writes ensure consistency. If two Lambdas attempt concurrent S3 uploads, one succeeds and the other retries with the latest bitstring.

Target: 99.9% first-attempt success rate under 10 concurrent Lambda invocations processing distinct bit_index ranges.

*Optimization:*

REVOKED #sym.arrow FREE transitions are skipped because both states map to bit=1 in S3. This saves unnecessary S3 uploads (~50% reduction for revoked credentials that expire).

==== Visual Workflow / Diagram

*Bitstring Update Flow:*

```
[Bitstring Index status change]
    |
    | DDB Stream event (CLAIMED/REVOKED/FREE transition)
    v
[DDB Streams]
    |
    | Batch up to 100 records
    v
[Bitstring Updater Lambda - Stream Event Source Mapping]
    |
    | 1. Extract bit_index + status from each record
    | 2. Filter: skip REVOKED -> FREE (1 -> 1)
    v
[Bitstring Updater Lambda]
    |
    | 3. Download bitstring from S3 with ETag
    v
[S3 - Revocation Bitstring]
    |
    | Returns bitstring bytes + ETag
    v
[Bitstring Updater Lambda]
    |
    | 4. Decompress bitstring
    | 5. Update bits:
    |    - CLAIMED: bit=0
    |    - REVOKED/FREE: bit=1
    | 6. Compress bitstring
    | 7. Upload with If-Match: ETag
    v
[S3 - Revocation Bitstring]
    |
    | If ETag matches: accept upload
    | If ETag changed: return 412 Precondition Failed
    v
[Bitstring Updater Lambda]
    |
    | If success: checkpoint stream
    | If failed: retry with fresh download
```

==== Schema

*Bitstring Index DDB Stream Record:*

```json
{
  "eventName": "MODIFY",
  "dynamodb": {
    "Keys": {
      "bit_index": { "N": "94567" }
    },
    "NewImage": {
      "bit_index": { "N": "94567" },
      "status": { "S": "REVOKED" },
      "credential_id": { "S": "uuid" },
      "version": { "N": "2" }
    },
    "OldImage": {
      "status": { "S": "CLAIMED" },
      "version": { "N": "1" }
    }
  }
}
```

==== API Specs --- Function Prototypes

*Function: process_stream_batch(records: []DynamoDBStreamRecord)*

- *Name:* process_stream_batch
- *Location:* src/bitstring_updater/handler.go:23
- *Input(s):*
  - records: Array of DDB Stream records from Bitstring Index table
- *Output: Success:* nil (batch processed, stream checkpointed)
- *Output: Error:*
  - Error: S3 download or upload failed
  - Error: ETag mismatch (concurrent S3 update), retry required
- *Description:* Processes batch of Bitstring Index changes. Filters records to skip REVOKED #sym.arrow FREE (1 #sym.arrow 1 transitions). Downloads S3 bitstring, modifies bits, uploads with ETag check.

*Function: extract_bit_updates(records: []DynamoDBStreamRecord)*

- *Name:* extract_bit_updates
- *Location:* src/bitstring_updater/stream.go:12
- *Input(s):*
  - records: Array of DDB Stream records
- *Output: Success:* []BitUpdate (filtered array of bit_index and new_status pairs)
- *Output: Error:* nil
- *Description:* Iterates through stream records, extracts bit_index and status from NewImage and OldImage. Filters out REVOKED #sym.arrow FREE transitions (both map to bit=1). Returns array of BitUpdate structs requiring S3 modification.

*Function: download_and_decompress_bitstring()*

- *Name:* download_and_decompress_bitstring
- *Location:* src/bitstring_updater/s3.go:12
- *Input(s):* None (fixed S3 bucket and key)
- *Output: Success:* ([]byte, string) - decompressed bitstring bytes and ETag
- *Output: Error:*
  - Error: S3 download failed
  - Error: GZIP decompression failed
- *Description:* Downloads bitstring.gz from S3, returns decompressed bytes and ETag for conditional writes

*Function: modify_bitstring_bits(bitstring: []byte, updates: []BitUpdate)*

- *Name:* modify_bitstring_bits
- *Location:* src/bitstring_updater/bitstring.go:34
- *Input(s):*
  - bitstring: Mutable bitstring bytes
  - updates: Array of BitUpdate (bit_index, new_status)
- *Output: Success:* nil (bitstring modified in-place)
- *Output: Error:* nil
- *Description:* For each update, computes byte position (index / 8) and bit offset (index % 8). Sets bit to 0 (status=CLAIMED) or 1 (status=REVOKED/FREE) using bitwise operations.

*Function: compress_and_upload_bitstring(bitstring: []byte, expected_etag: string)*

- *Name:* compress_and_upload_bitstring
- *Location:* src/bitstring_updater/s3.go:56
- *Input(s):*
  - bitstring: Decompressed bitstring bytes
  - expected_etag: ETag from S3 GetObject response
- *Output: Success:* string (new ETag from successful upload)
- *Output: Error:*
  - Error: S3 upload failed
  - Error: ETag mismatch (HTTP 412 Precondition Failed), retry required
- *Description:* Compresses bitstring using gzip, uploads to S3 with If-Match: expected_etag header for conditional write. If ETag matches (no concurrent update), S3 accepts upload and returns new ETag. If ETag changed (concurrent update occurred), S3 returns 412 error and caller retries with fresh download.

==== Dependencies on Other Components

- *Bitstring Index DDB Streams:* Lambda is triggered by Stream events. If Streams is unavailable, bit updates don't propagate to S3 but stream records are retained and processed when service recovers.

- *Bitstring Index Table:* Lambda depends on DDB Streams to receive bit status change events. If table is unavailable, no new stream records are generated but existing stream backlog continues processing.

- *S3 Revocation Bitstring:* Lambda depends on S3 to download and upload bitstring. If S3 is unavailable, Lambda retries with exponential backoff. Existing bitstring remains accessible to verifiers during S3 outage.

==== Trade-offs

*DDB Streams vs. Direct S3 Updates from Multiple Lambdas:*

Using DDB Streams to trigger a single Bitstring Updater Lambda instead of having each Lambda (Issuer, Free) directly update S3 prevents race conditions and simplifies concurrency control. Direct updates would require coordination logic in every Lambda. Streams add 100-500ms latency but provide guaranteed delivery and automatic batching. The trade-off prioritizes consistency and architectural simplicity over minimal latency.

*Batch Processing vs. Individual Processing:*

Processing stream records in batches of up to 100 reduces S3 uploads compared to processing each record individually. A batch of 100 changes requires one S3 download, one modification, and one upload, versus 100 separate S3 round trips. This improves throughput by ~50x and reduces costs. However, batching increases latency (up to 1 second batching window). The trade-off prioritizes throughput and S3 cost efficiency over minimal latency.

*ETag-Based Conditional Writes vs. DynamoDB Version Locking:*

Using S3 ETag-based conditional writes instead of DynamoDB version locking simplifies architecture by eliminating separate metadata table. ETags are automatically generated by S3 and provide built-in concurrency control. ETag conflicts require re-downloading entire bitstring (~1.25KB), whereas DDB version conflicts only require re-reading metadata (~100 bytes). For MVP bitstring size (\<2KB), this overhead is negligible. The trade-off prioritizes architectural simplicity over micro-optimization.

*Filtering REVOKED -> FREE vs. Processing All Transitions:*

Filtering out REVOKED #sym.arrow FREE transitions (both map to bit=1) reduces unnecessary S3 uploads by ~50% for revoked credentials that expire. This optimization requires checking OldImage and NewImage in stream records. Alternative would be simpler code (process all transitions) but higher S3 costs. The trade-off prioritizes cost optimization over code simplicity.

=== AWS API Gateway

==== Purpose

API Gateway provides HTTPS endpoints for credential issuance and revocation requests, routes requests to Issuance Lambda or Revocation Processor Lambda, and enforces rate limiting to prevent abuse.

==== Requirements Supported

- Signed credential is delivered to user's wallet via secure channel (HTTPS)
- Users can submit revocation requests
- System protects against abuse through rate limiting

==== Detailed Design

API Gateway is configured with two routes:

1. POST /api/v1/credentials/issue #sym.arrow Lambda Proxy Integration to Issuance Lambda
2. POST /api/v1/credentials/revoke #sym.arrow Lambda Proxy Integration to Revocation Processor Lambda

All routes use HTTPS with TLS 1.3. API Gateway is deployed in all regions (us-east-1, us-east-2, us-west-2) with Route 53 latency-based routing to direct users to nearest region.

Rate limiting is enforced using API Gateway Usage Plans:

- 100 requests per minute per IP address for issuance endpoint
- 50 requests per minute per IP address for revocation endpoint

==== API Specs --- Function Prototypes

*Endpoint: POST /api/v1/credentials/issue*

- *Name:* Credential Issuance Endpoint
- *Input(s):*
  - Body: JSON with authorization_code and code_verifier
  - Headers: Content-Type: application/json
- *Output: Success:* HTTP 201 Created with signed credential in response body
- *Output: Error:*
  - 400 Bad Request: Missing or malformed authorization_code
  - 401 Unauthorized: Invalid authorization code
  - 409 Conflict: Active credential already exists for this subject
  - 429 Too Many Requests: Rate limit exceeded
  - 503 Service Unavailable: Keycloak IdP unavailable or Lambda throttled
- *Rate Limit:* 100 requests/minute per IP

*Endpoint: POST /api/v1/credentials/revoke*

- *Name:* Credential Revocation Endpoint
- *Input(s):*
  - Body: JSON with credential_id and revocation_proof
  - Headers: Content-Type: application/json
- *Output: Success:* HTTP 202 Accepted with message "Revocation request received, processing asynchronously"
- *Output: Error:*
  - 400 Bad Request: Invalid credential_id or proof format
  - 429 Too Many Requests: Rate limit exceeded
- *Rate Limit:* 50 requests/minute per IP
- *Note:* Endpoint calls Revocation Processor Lambda and returns HTTP 202 immediately (async processing). Revocation Processor Lambda validates proof and updates Credential Metadata. Free Lambda updates Bitstring Index. Bitstring Updater updates S3. Full propagation takes seconds.

==== Dependencies on Other Components

- *Issuance Lambda:* API Gateway invokes Issuance Lambda for /credentials/issue endpoint. If Lambda is throttled or unavailable, API Gateway returns 503.

- *Route 53:* API Gateway depends on Route 53 latency-based routing to direct users to nearest region. If Route 53 is unavailable, users can still access API Gateway via direct regional endpoint.

==== Trade-offs

*Regional API Gateway vs. Single Region:*

Deploying API Gateway in multiple regions (us-east-1, us-east-2, us-west-2) with Route 53 latency-based routing reduces latency for users in different geographic locations but increases infrastructure complexity (multi-region deployment via Terraform). For credential issuance, minimizing OAuth callback latency improves user experience. The trade-off prioritizes user experience over deployment simplicity.

=== AWS Secrets Manager

==== Purpose

Secrets Manager stores sensitive cryptographic keys (Baby Jubjub EdDSA issuer private key, HMAC key for subject identifier pseudonymization) and provides secure access to Lambda functions with automatic rotation support.

==== Requirements Supported

- Support key management practices including key rotation and least-privilege access
- Protect cryptographic keys in storage and during transmission

==== Detailed Design

Two secrets are stored in Secrets Manager:

1. *Baby Jubjub EdDSA Issuer Private Key:* Used by Issuance Lambda to sign individual credential fields. Key is generated offline during initial setup and uploaded to Secrets Manager. Key rotation is manual (requires re-issuance of all credentials).

2. *HMAC Key:* Used by Issuance Lambda to compute pseudonymous subject identifiers. Key rotation is supported via automatic rotation (Lambda function updates all DynamoDB records with new HMAC values).

Lambda functions retrieve secrets during cold start and cache in memory for execution environment lifetime (15 minutes). This reduces Secrets Manager API calls and improves performance.

==== Schema

*Baby Jubjub EdDSA Issuer Private Key Secret:*

```json
{
  "key_id": "zeroverify-issuer-2025",
  "algorithm": "EdDSA_BabyJubJub",
  "private_key_bytes": "base64_encoded_scalar",
  "created_at": "2025-01-15T00:00:00Z",
  "rotation_policy": "manual"
}
```

*HMAC Key Secret:*

```json
{
  "key_id": "zeroverify-hmac-2025",
  "algorithm": "HMAC-SHA256",
  "key_bytes": "base64_encoded_32_bytes",
  "created_at": "2025-01-15T00:00:00Z",
  "rotation_policy": "automatic_90_days"
}
```

==== Dependencies on Other Components

- *Issuance Lambda:* Depends on Secrets Manager to retrieve Baby Jubjub EdDSA private key and HMAC key. If Secrets Manager is unavailable during cold start, Lambda returns HTTP 503. Keys are cached in memory, so Secrets Manager unavailability after cold start does not affect issuance.

- *Revocation Processor, Free Lambda, Bitstring Updater Lambda:* Do not depend on Secrets Manager (revocation and bit management do not require signing operations).

==== Trade-offs

*Secrets Manager vs. AWS KMS:*

Secrets Manager is used instead of AWS KMS because KMS does not support Baby Jubjub EdDSA signatures (not a NIST-standardized algorithm). KMS supports only NIST-approved algorithms (RSA, ECDSA, AES). Secrets Manager allows storing arbitrary binary secrets. The trade-off accepts manual key rotation for Baby Jubjub EdDSA keys (KMS provides automatic rotation for supported algorithms) in exchange for Baby Jubjub EdDSA support.

*In-Memory Caching vs. Per-Request Retrieval:*

Lambda functions cache secrets in memory for 15 minutes instead of retrieving from Secrets Manager on every invocation. This reduces Secrets Manager API calls by approximately 99% (one call per cold start vs. one call per invocation) and eliminates Secrets Manager latency (~50ms per call) from the critical path. The trade-off accepts stale secrets for up to 15 minutes after rotation in exchange for performance. For key rotation events, all warm Lambda execution environments must expire before new key takes full effect.

= Development Plan

== Testing Plan

Testing is structured in two categories: Unit Tests and Integration Tests. This section does not enumerate every individual test case but defines the categories and representative tests within each.

=== Unit Tests

Unit tests focus on individual functions or components in isolation. Tests are fast (\<100ms per test) and validate both success and failure conditions. Tests do not require external dependencies (mocked or stubbed).

*Representative Unit Tests:*

*Issuance Lambda:*
- compute_subject_id() accepts string inputs and returns base64-encoded HMAC-SHA256 hash
- compute_subject_id() returns consistent output for same inputs across multiple invocations
- sign_credential() generates valid Baby Jubjub EdDSA signatures for each credential field
- sign_credential() fails when private key is malformed (error handling test)
- check_existing_credential() returns None when no active credentials exist
- check_existing_credential() returns Some(record) when active credential exists with status=ACTIVE and expires_at > now
- claim_free_bit_index() succeeds with random index selection and conditional write (mocked DynamoDB)

*Revocation Processor Lambda:*
- validate_revocation_proof() returns true for valid zk-SNARK proof
- validate_revocation_proof() returns false for tampered proof (public inputs modified)
- update_credential_status() sets Credential Metadata status to REVOKED

*Free Lambda:*
- handle_credential_event() correctly parses DDB Stream events (explicit revocation)
- handle_credential_event() correctly parses DDB TTL events (automatic expiry)
- free_bit_index() updates Bitstring Index status (CLAIMED #sym.arrow REVOKED, any #sym.arrow FREE)

*Bitstring Updater Lambda:*
- extract_bit_updates() filters out REVOKED #sym.arrow FREE transitions (1 #sym.arrow 1, no change)
- modify_bitstring_bits() sets bit at index 94567 to 1 when status=REVOKED/FREE
- modify_bitstring_bits() sets bit at index 94567 to 0 when status=CLAIMED
- compress_and_decompress_bitstring() round-trip produces identical bytes

*Browser Wallet:*
- parseVerificationRequest() extracts proof_type, verifier_id, challenge, callback from URL query parameters
- parseVerificationRequest() returns null when required parameter is missing
- generatePKCEChallenge() produces base64url-encoded SHA-256 hash of verifier
- storeCredentialInIndexedDB() encrypts credential before storing
- loadCredentialFromIndexedDB() decrypts credential after retrieval and returns original plaintext

*Success/Failure Conditions:*
- Success: Function returns expected output type with correct values
- Failure: Function throws expected error type or returns None/null when inputs are invalid

=== Integration Tests

Integration tests validate workflows involving multiple components. Tests are slower (\<5 seconds per test) and may require external dependencies (LocalStack, test Keycloak instance). Tests map directly to user flows from the UI/UX document.

*Representative Integration Tests:*

*Credential Issuance Flow:*
1. User authenticates with mock Keycloak IdP (returns authorization code)
2. Browser wallet calls POST /api/v1/credentials/issue with code and verifier
3. Issuance Lambda exchanges code with Keycloak (mocked response with OIDC claims)
4. Lambda computes subject_id and queries DynamoDB (no existing credential)
5. Lambda signs credential and inserts metadata into DynamoDB
6. Lambda returns signed credential to wallet
7. Wallet stores credential in IndexedDB
8. Success: Credential exists in IndexedDB and DynamoDB record has status=ACTIVE

*Proof Generation and Verification Flow:*
1. User opens verifier link with proof_type=student_status, challenge=abc123
2. Wallet loads credential from IndexedDB
3. Wallet fetches proving key from mocked S3 endpoint
4. Wallet generates zk-SNARK proof using snarkjs
5. Wallet posts proof to mock verifier callback endpoint
6. Mock verifier validates proof against verification key
7. Mock verifier downloads revocation bitstring from mocked S3 endpoint
8. Mock verifier checks bit at revocation_index (bit = 0, not revoked)
9. Success: Verifier receives "valid" result

*Revocation Flow:*
1. User submits revocation request with credential_id and proof
2. Revocation Processor Lambda triggered
3. Lambda validates revocation proof (zk-SNARK proof of credential ownership)
4. Lambda queries DynamoDB for revocation_index
5. Lambda downloads bitstring from mocked S3, modifies bit at revocation_index to 1
6. Lambda uploads updated bitstring to S3
7. Lambda updates DynamoDB record status to REVOKED
8. Success: DynamoDB record has status=REVOKED and bitstring has bit at revocation_index = 1

*Replay Attack Prevention:*
1. Verifier generates unique challenge nonce and stores it in their own database
2. User generates proof with challenge=xyz789 and submits to verifier
3. Verifier validates proof and marks challenge as consumed in their own database
4. Attacker attempts to resubmit same proof with same challenge
5. Verifier queries their database and finds challenge already consumed
6. Success: Verifier rejects proof with error "challenge_consumed"
Note: Replay protection is verifier's responsibility. ZeroVerify does not track challenge nonces.

*IdP Unavailability Handling:*
1. User initiates credential issuance
2. Keycloak redirects to university IdP
3. IdP is unreachable (network timeout simulated)
4. Keycloak returns HTTP 503 to wallet
5. Success: Wallet displays "University login service temporarily unavailable" without crashing

*Success/Failure Conditions:*
- Success: Entire workflow completes with expected final state (credential stored, proof verified, revocation applied)
- Failure: Workflow fails at expected point with expected error message (IdP unavailable, invalid proof, replay detected)

== Task Breakdown

=== Implementation Dependencies

The following tasks have dependencies where one task cannot begin until another is complete. This establishes the critical path of implementation.

*Critical Path:*

1. *Infrastructure Setup (Terraform):* Must complete before any component deployment
   - DynamoDB tables
   - S3 buckets
   - API Gateway configuration
   - Lambda IAM roles
   - Secrets Manager secrets

2. *Keycloak Deployment and IdP Configuration:* Depends on infrastructure setup
   - Deploy Keycloak in Docker Compose (local) or ECS (staging)
   - Configure realm for ZeroVerify
   - Register test IdP (mock university Shibboleth endpoint)

3. *Circuit Trusted Setup:* Must complete before proof generation or verification
   - Generate Circom circuits for proof types (student_status, age_over_21)
   - Run trusted setup (powers of tau ceremony, circuit-specific setup)
   - Generate proving key and verification key
   - Upload proving keys to S3
   - Publish verification key to verifier SDK

4. *Issuance Lambda Implementation:* Depends on infrastructure setup, Keycloak, Secrets Manager
   - Cannot begin until Baby Jubjub EdDSA private key is generated and stored in Secrets Manager
   - Cannot test end-to-end until Keycloak is configured

5. *Browser Wallet Implementation:* Depends on Issuance Lambda API, S3 circuit storage
   - Credential issuance UI cannot be tested until Issuance Lambda is deployed
   - Proof generation cannot be tested until circuits and proving keys are uploaded to S3

6. *Revocation Architecture Implementation:* Depends on infrastructure setup (DDB Streams, TTL configuration), S3 bitstring storage
   - Cannot test until DynamoDB tables are deployed
   - Cannot test concurrency until multiple Lambda invocations can be triggered

7. *Verifier SDK Implementation:* Depends on circuit trusted setup (verification key)
   - Cannot verify proofs until verification key is available

8. *Integration Testing:* Depends on all components deployed
   - Cannot test end-to-end flows until Browser Wallet, Issuance Lambda, Revocation Architecture (3 Lambdas), and Verifier SDK are complete

*Non-Blocking Tasks (can proceed in parallel):*

- Browser Wallet UI design (can proceed while Lambdas are being implemented)
- Documentation writing (can proceed while implementation is ongoing)
- Unit test writing (can proceed alongside component implementation)

= Future Improvements

The following features are out of MVP scope but worth preserving for post-MVP iterations:

*Credential Updates and Amendments:*

Support in-place credential updates without requiring revocation and re-issuance. For example, if a student changes their major, the institution could issue an amendment to the existing credential rather than revoking and re-issuing. Requires versioning mechanism in W3C Verifiable Credentials and amendment signing protocol.

*Mobile Native Applications:*

Build native iOS and Android apps for improved performance and hardware-backed credential storage (iOS Secure Enclave, Android Keystore). Native apps would reduce proof generation time by approximately 30-40% compared to WebAssembly in browser. Requires app store distribution and platform-specific cryptographic library integration.

*Cross-Device Credential Sync:*

Allow users to sync credentials across multiple devices (desktop, mobile, tablet) using encrypted cloud backup or device-to-device transfer. Requires secure key derivation protocol, cloud storage integration (iCloud, Google Drive), and conflict resolution for concurrent updates.

*Offline Proof Generation:*

Cache circuit proving keys locally to enable proof generation without internet access. Requires implementing service worker for offline asset caching and fallback logic when proving keys cannot be fetched from S3.

*Batch Proof Generation:*

Allow users to generate multiple proofs for different verifiers simultaneously. For example, a user could approve proof generation for Spotify (student status) and Adobe (student status) in a single UI flow. Requires queuing mechanism and progress UI showing per-verifier proof generation status.

*User-Initiated Self-Revocation UI:*

Add self-service revocation button in wallet UI so users can revoke credentials without generating zk-SNARK proof of ownership. Requires authentication mechanism to prevent unauthorized revocation (e.g., re-authenticate with IdP before revocation).

*Verifier Reputation and Whitelisting:*

Provide verifier reputation scores or curated whitelist of trusted verifiers in wallet UI. Requires centralized verifier registry, reputation scoring algorithm, and governance process for adding verifiers to whitelist.

*Granular Role-Based Credentials:*

Support credentials with multiple roles or permissions within a single credential. For example, a university credential could include roles for student, teaching assistant, and library access. Requires multi-attribute circuits and selective disclosure of specific roles during proof generation.

*Credential Expiration Notifications:*

Send users email or push notifications when credentials are approaching expiration (e.g., 30 days before expiration). Requires user email registration, notification service integration (SNS, SendGrid), and opt-in mechanism for notifications.

*Audit Logs for Verifier Access:*

Allow users to view audit log showing which verifiers requested proofs and when. Requires storing verification events in DynamoDB without logging proof contents (only verifier_id, proof_type, timestamp).

*Support for Additional Proof Types:*

Add circuits for additional proof types beyond student_status and age_over_21, such as:
- Employment status (employed at specific company)
- Professional licensure (holds valid medical license)
- Income verification (income above threshold without revealing exact amount)
- Geographic location (resident of specific state/country)

Each proof type requires custom Circom circuit design, trusted setup, and proving key generation.

*Performance Optimizations:*

- Implement CloudFront CDN for S3 bitstring and circuit artifact distribution to reduce verifier download latency
- Use AWS Lambda Provisioned Concurrency to eliminate cold starts during peak traffic periods
- Migrate DynamoDB from On-Demand to Provisioned Capacity with auto-scaling once traffic patterns are established
- Implement Redis caching layer for DynamoDB credential metadata lookups to reduce query latency

*Enhanced Error Reporting:*

Provide structured error responses with error codes, debug identifiers, and actionable remediation steps. For example, instead of "Authentication failed," return:

```json
{
  "error_code": "idp_claim_missing",
  "message": "Required claim 'enrollment_status' not returned by IdP",
  "debug_id": "a3f8b2c1-4d5e-6f7a-8b9c-0d1e2f3a4b5c",
  "remediation": "Contact university IT support to enable enrollment_status claim in SAML assertion"
}
```

Requires error taxonomy, debug identifier tracking, and user-facing error documentation.
