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

The student discount market is growing to #link("https://growthmarketreports.com/report/student-discount-platforms-market")[\$19.3 billion by 2033]. Right now, students give up tons of personal data just to prove they're students. For a \$5 Spotify discount, you upload your driver's license to #link("https://www.sheerid.com/")[SheerID]\; they see your full name, birthdate, address, and photo. They keep this data for #link("https://www.sheerid.com/global-privacy-policy/")[as long as the account stays active] in centralized databases.

Apple just launched #link("https://www.apple.com/newsroom/2025/11/apple-introduces-digital-id-a-new-way-to-create-and-present-an-id-in-apple-wallet/")[Digital ID] with privacy features, proving that better verification is possible. The timing is right: growing market, clear privacy problem, and validated technology.

= 2. The Problem (The Gap)

The market has a gap. #link("https://www.vendr.com/buyer-guides/sheerid")[SheerID] gives merchants real-time verification but collects excessive data: IP addresses, device IDs, blocks VPNs. #link("https://www.apple.com/newsroom/2025/11/apple-introduces-digital-id-a-new-way-to-create-and-present-an-id-in-apple-wallet/")[Apple's Digital ID] uses selective disclosure, which shows merchants some real identity data (like your actual birthdate or university name) but hides other fields. Merchants still receive enough information to track and profile users across services.

No solution gives merchants real-time student verification while exposing zero personal information, not even which university you attend or when you were born.

= 3. The Solution: ZeroVerify

ZeroVerify uses zero-knowledge proofs to verify students without exposing personal data. Here's how it works:

1. Student authenticates with their university via OAuth (single sign-on)
2. Our service creates a signed credential and sends it directly to the student's browser
3. Student stores the credential encrypted in a browser wallet
4. When verification is needed, the wallet generates a mathematical proof
5. Merchant receives the proof and verifies it\; learns only "this person is a student"

The merchant never sees your name, university, graduation date, or any personal information. The credential stays on your device. Only the proof gets sent.

= 4. Technical Approach & Depth

- *Tech Stack:* TypeScript/React browser wallet (web-based, works on any modern browser across Windows, Mac, Linux, Android, iOS), serverless backend using AWS Lambda functions with Terraform for infrastructure, ECDSA P-256 signatures with AWS KMS for key management.

- *Cryptographic Complexity:* We use zero-knowledge SNARKs implemented with #link("https://docs.circom.io/")[Circom] circuits that compile to WebAssembly. The browser generates proofs using #link("https://github.com/iden3/snarkjs")[snarkjs]. The proof demonstrates "I have a valid credential from an accredited university AND it hasn't expired" without revealing the actual credential data.

- *Engineering Merit:* We implement the #link("https://www.w3.org/TR/vc-data-model-2.0/")[W3C Verifiable Credentials 2.0] standard for interoperability. OAuth/OIDC integration means we can issue credentials to students at any university immediately, no agreements needed.

= 5. Novelty & USP (Unique Selling Point)

Our USP is zero-knowledge verification. Proof without any data disclosure. Unlike SheerID's database matching or Apple's selective disclosure (which shows real  birthdates/universities to merchants), we expose nothing. The proof demonstrates "currently enrolled student" without revealing name, university, or graduation date.

We don't retain student data. OAuth confirms enrollment, we issue a signed credential directly to the student's browser, then we forget everything. No centralized database of student information.

Unlike Apple's Digital ID (iOS-only, requires Apple API integration) or campus student IDs (requires bilateral university agreements for NFC infrastructure), we're web-based and cross-platform. The wallet runs in any modern browser on any device. ZK proofs work across web, mobile, desktop with standard HTTP APIs.

We're more private than Apple and don't need SheerID's data infrastructure.

= 6. Broader Impact

- *Economic:* Students stop surrendering driver's licenses for \$5 discounts.

- *Legal/Regulatory:* GDPR and CCPA both require data minimization. We collect less data than SheerID, so we're compliant by design. The EU passed a digital identity regulation in May 2024 that requires zero-knowledge proofs, which validates our technical approach and might influence future U.S. privacy laws.

- *Technological:* Proves browser-based ZK cryptography works for consumer applications. The foundation extends beyond student verification to any attribute-based verification: age, employment status, professional licenses, where proof without disclosure is valuable.

= 7. Limitations and Tradeoffs

- *Credential Revocation*: We implement #link("https://www.w3.org/TR/vc-bitstring-status-list/")[W3C Bitstring Status Lists] for revocation. Students can revoke their own credentials by generating a ZK proof that demonstrates ownership, which our API verifies cryptographically before updating the status list. We also use time-based expiration (credentials valid for one semester) to handle normal lifecycle. This matches how SheerID works; they also don't dynamically revoke when students graduate mid-semester.

- *Proof Generation Cost*: Generating ZK Proofs takes 2-5 seconds on modern devices. This is more compute-intensive than submitting a SheerID form. However, it is faster than uploading the document and waiting for manual approval. The computational cost shifts from servers to student's device.

- *Browser Security vs Apple's hardware wallet*: Browser-based credentials storage is less secure than Apple's secure element. However, our architecture never transmits the credentials. Credentials always stay on the device, and only ZK proofs are sent. Even if someone compromises browser storage, they get only one student's credentials, not a centralized database of millions. Apple's approach is more secure, but their selective disclosure still sends identity data. We trade hardware-level security for zero data disclosure.  

- *Trust*: Merchants trust our mechanism through cryptographic verification, not reputation. The ZK proof is mathematically verifiable using our public key; if it verifies, the credential was genuinely issued by us and hasn't been tampered with. We only issue credentials after university OAuth confirms enrollment, so we're not the source of truth, universities are. Merchants can audit our public key and verification code for transparency. SheerID offers broader coverage through #link("https://www.sheerid.com/press-releases/sheerid-expands-identity-verification-platform-with-marketing-hub-and-dataconnectors-to-400-martech-solutions/")[200,000+ data sources] but requires collecting excessive student data. We offer cryptographic certainty with zero data collection. Initial adoption requires pilots with privacy-conscious brands.


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
