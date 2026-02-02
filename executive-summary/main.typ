#set page(
  paper: "us-letter",
  margin: (x: 1in, y: 1in),
)

#set par(justify: true)
#show link: underline

#align(center)[
  #text(size: 16pt, weight: "bold")[
    Executive Summary: Project "ZeroVerify"
  ]
  
  #v(0.3em)
  
  #text(size: 13pt)[
    Privacy-Preserving Verification System
  ]
  
  #v(0.3em)
  
  #text(size: 11pt)[
    Team Members: Lisa Nguyen, Anton Sakhanovych, Souleymane Sono, Fateha Ima, Simon Griemert
  ]
  
  #v(1.5em)
]

= 1. The Hook (The "Why Now")

Attribute verification is broken across markets: the student discount market #link("https://growthmarketreports.com/report/student-discount-platforms-market")[\$19.3 billion by 2033], age  verification (\$1.2B by 2028), employment verification for corporate benefits. People surrender excessive personal data to prove simple facts. For a \$5 Spotify discount, students upload driver's licenses to #link("https://www.sheerid.com/")[SheerID], full name, birthdate, address, photo, stored in centralized databases. Seniors proving age eligibility, employees accessing corporate perks, professionals showing licensure all face the same problem: verification requires exposing identity data that services don't need. Apple's Digital ID and the EU's May 2024 regulation requiring zero-knowledge proofs validate that better verification is possible. The timing is right: growing markets, clear privacy problem, proven technology.

= 2. The Problem (The Gap)

The market has a gap. #link("https://www.vendr.com/buyer-guides/sheerid")[SheerID] gives merchants real-time verification but collects excessive data: IP addresses, device IDs, blocks VPNs. #link("https://www.apple.com/newsroom/2025/11/apple-introduces-digital-id-a-new-way-to-create-and-present-an-id-in-apple-wallet/")[Apple's Digital ID] uses selective disclosure, which shows merchants some real identity data (actual birthdate, university name, employer) but hides other fields. Merchants still receive enough information to track and profile users across services. 

*Target Users*: Primary users are individuals proving attributes (students, employees, seniors, veterans, licensed professionals) who want verification without exposing personal data. Secondary stakeholders are service providers integrating our API to verify attributes without storing personal data, and credential issuers (universities, employers, agencies, licensing boards) who use OAuth to let us issue credentials after authentication, offloading verification infrastructure while remaining the source of truth.

= 3. The Solution: ZeroVerify

ZeroVerify uses zero-knowledge proofs for attribute verification without data disclosure. 
Here's how it works:

1. User authenticates with credential issuer via OAuth (university for enrollment, employer for employment status, government agency for age/veteran status, licensing board for professional credentials)
2. Our service creates a signed credential and sends it directly to the user's browser
3. User stores the credential encrypted in a browser wallet
4. When verification is needed, the wallet generates a mathematical proof
5. Merchant receives the proof and verifies it\; learns only "this person has an attribute X"

The merchant never sees your name, university, graduation date, or any personal information. The credential stays on your device. Only the proof gets sent.

= 4. Technical Approach & Depth

- *Tech Stack:* TypeScript/React browser wallet (web-based, works on any modern browser across Windows, Mac, Linux, Android, iOS), serverless backend using AWS Lambda functions with Terraform for infrastructure, ECDSA P-256 signatures with AWS KMS for key management.

- *Cryptographic Complexity:* We use zero-knowledge SNARKs implemented with #link("https://docs.circom.io/")[Circom] circuits that compile to WebAssembly. The browser generates proofs using #link("https://github.com/iden3/snarkjs")[snarkjs]. The proof demonstrates "I have a valid credential from an accredited university AND it hasn't expired" without revealing the actual credential data.

- *Engineering Merit:* We use #link("https://www.w3.org/TR/vc-data-model-2.0/")[W3C Verifiable Credentials 2.0] and OAuth/OIDC to support any identity provider, eliminating the need for bilateral agreements.

- *Technical Superiority*: We use zkSNARKs over Bulletproofs because SNARKs produce constant-size proofs #link("https://alinush.github.io/groth16")[(~200 bytes)] regardless of statement complexity. Bulletproofs scale logarithmically with circuit size. For merchant verification, constant proof size means predictable bandwidth. SNARK verification is O(1), Bulletproof verification is O(n). The tradeoff is trusted setup, mitigated through multi-party computation with public transcripts. We chose W3C Bitstring Status Lists over OCSP for privacy-preserving revocation. OCSP requires querying a server with the credential ID, revealing which credential is being verified. Bitstrings allow merchants to download a compact list (~1KB for 10,000 credentials) and check revocation locally without revealing which credential they're verifying. We chose BBS+ signatures over ECDSA for selective disclosure. ECDSA requires the entire credential in the ZK circuit to prove any attribute. BBS+ proves only required attributes (e.g., enrollment status) without processing unnecessary fields, reducing circuit complexity.
= 5. Novelty & USP (Unique Selling Point)

Our USP is zero-knowledge verification. Proof without any data disclosure. Unlike SheerID's database matching or Apple's selective disclosure (which reveals actual attribute values to verifiers), we expose nothing. The proof demonstrates a valid attribute (e.g., "currently enrolled", "over 21", "licensed professional") without revealing the underlying data.

We don't retain user data. OAuth confirms the attribute with the authoritative source, we issue a signed credential directly to the user's browser, then we forget everything. No centralized database of user information.

Unlike Apple's Digital ID (iOS-only, requires Apple API integration) or institution-specific solutions (require bilateral agreements), we're web-based and cross-platform. The wallet runs in any modern browser on any device. ZK proofs work across web, mobile, desktop with standard HTTP APIs.

= 6. Broader Impact

- *Economic:* Users stop surrendering identity documents for routine verifications like discounts, benefits, or service access.

- *Legal/Regulatory:* GDPR and CCPA both require data minimization. We collect less data than SheerID, so we're compliant by design. The EU passed a digital identity regulation in May 2024 that requires zero-knowledge proofs, which validates our technical approach and might influence future U.S. privacy laws.

- *Technological:* Proves browser-based ZK cryptography works for consumers. Extends to any attribute verification (age, employment, licensure) where proof without disclosure is valuable.

= 7. Limitations and Tradeoffs

- *Credential Revocation*: We implement #link("https://www.w3.org/TR/vc-bitstring-status-list/")[W3C Bitstring Status Lists] rather than PKI mechanisms (CRL/OCSP) because bitstrings preserve verification privacy. #link("https://datatracker.ietf.org/doc/html/rfc5280")[CRL] requires merchants to download lists of revoked credential identifiers, creating linkability. #link("https://en.wikipedia.org/wiki/Online_Certificate_Status_Protocol")[OCSP] requires real-time queries with credential identifiers, exposing verification patterns. Bitstrings encode revocation as bit positions in a compressed list; merchants fetch the bitstring, check the relevant bit locally, reveal nothing about which credential they're verifying. Users self-revoke by generating ZK proofs of credential ownership. Time-based expiration handles normal lifecycle without revocation overhead.

- *Proof Generation Cost*: Generating ZK Proofs takes 2-5 seconds on modern devices. This is more compute-intensive than submitting a SheerID form. However, it is faster than uploading the document and waiting for manual approval. The computational cost shifts from servers to user's device.

- *Browser Security vs Apple's hardware wallet*: Browser-based credentials storage is less secure than Apple's secure element. However, our architecture never transmits the credentials. Credentials always stay on the device, and only ZK proofs are sent. Even if someone compromises browser storage, they get only one user's credentials, not a centralized database of millions. Apple's approach is more secure, but their selective disclosure still sends identity data. We trade hardware-level security for zero data disclosure.  

- *Trust*: Merchants trust our mechanism through cryptographic verification, not reputation. The ZK proof is mathematically verifiable using our public key; if it verifies, the credential was genuinely issued by us and hasn't been tampered with. We issue credentials only after OAuth confirmation from the authoritative source; the issuer is the source of truth, not us. Merchants can audit our public key and verification code for transparency. SheerID offers broader coverage through #link("https://www.sheerid.com/press-releases/sheerid-expands-identity-verification-platform-with-marketing-hub-and-dataconnectors-to-400-martech-solutions/")[200,000+ data sources] but requires collecting excessive user data. We offer cryptographic certainty with zero data collection. Initial adoption requires pilots with privacy-conscious brands.


#pagebreak()

= References

+ Student Discount Platforms Market Research Report. Growth Market Reports. #link("https://growthmarketreports.com/report/student-discount-platforms-market")

+ SheerID Software Pricing and Business Model. Vendr. #link("https://www.vendr.com/buyer-guides/sheerid")

+ Apple introduces Digital ID, a new way to create and present an ID in Apple Wallet. Apple Newsroom, November 2025. #link("https://www.apple.com/newsroom/2025/11/apple-introduces-digital-id-a-new-way-to-create-and-present-an-id-in-apple-wallet/")

+ Google Wallet Adds Digital ID Support and Expands its Reach. PaymentsJournal. #link("https://www.paymentsjournal.com/google-wallet-adds-digital-id-support-and-expands-its-reach/")

+ Student IDs on iPhone and Apple Watch expand to Canada and more US universities. Apple Newsroom, August 2021. #link("https://www.apple.com/newsroom/2021/08/student-ids-on-iphone-and-apple-watch-expand-to-canada-and-more-us-universities/")

+ Circom: A Circuit Compiler for Zero-Knowledge Proofs. Documentation. #link("https://docs.circom.io/")

+ snarkjs: JavaScript implementation of zkSNARK schemes. GitHub - iden3. #link("https://github.com/iden3/snarkjs")

+ Verifiable Credentials Data Model 2.0. W3C Recommendation, May 2025. #link("https://www.w3.org/TR/vc-data-model-2.0/")

+ Polygon ID Release 6: Dynamic Credentials Implementation. Polygon Labs, February 2024. #link("https://polygon.technology/blog/polygon-id-release-6-introducing-the-first-ever-implementation-of-dynamic-credentials")

+ Bitstring Status List v1.0. W3C Recommendation, May 2025. #link("https://www.w3.org/TR/vc-bitstring-status-list/")
