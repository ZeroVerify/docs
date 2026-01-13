#set page(
  paper: "us-letter",
  margin: (x: 1in, y: 1in),
)

#show link: underline

#set heading(numbering: "1.")

#align(center)[
  #text(size: 20pt, weight: "bold")[
    Zero-Knowledge Verification System
  ]
  
  #text(size: 12pt)[
    Detailed idea proposal for my team.
  ]
  #v(0.5em)
  
  #text(size: 12pt, style: "italic")[
    CSI 4999 
  ]

  #text(size: 12pt)[
    Anton Sakhanovych
  ]
  
  #v(2em)
]

= The Problem
Students surrender massive amounts of personal information just to get basic discounts. To prove "I'm a student" for a \$5 Spotify discount, you must upload your driver's license showing your full name, exact birthdate, home address, photo, and more to companies like SheerID. These companies store this data in centralized databases that become targets for breaches.
The main issue is that verifiers need one bit of information(e.g. "is this person a student?") but current systems require exposing dozens of data points.

= Our solution

Students receive digitally-signed credentials from our service. Our service gets the information about the user via OAuth or SAML. These credentials are stored encrypted in a browser wallet. When verification is needed, the wallet generates a zero-knowledge proof, a cryptographic proof that demonstrates credential validity without exposing any credential contents.

For example:
Instead of uploading your full student ID, you generate a mathematical proof that says "I have a valid credential signed by an accredited university AND it hasn't expired." The verifier learns only "this person is currently a student." They don't learn your name, which university, your graduation date, or anything else.

The innovation here is that the credential stays on your device, only the proof gets sent to the verifier.

= Architecture

1. Issuer(our service): Authenticates students via university OAuth, creates and signs credentials, and immediately sends credentials to student's browser. We do not store credentials or student personal data.
2. Holder(student): Stores credentials encrypted in broswer wallet, generates zero-knowledge proofs when needed, controls when and where to share proofs.
3. Verifier(Spotify, Intellij, etc): Receives proofs, verifies them mathematically, grants access without seeing personal data.

Data flow: Student authenticates with university -> university confirms enrollment via OAuth -> our services creates signed credential -> credential sent immediately to the student's browser -> student stores in a wallet -> when verification is needed, generates proof from credential -> sends proof to verifier -> verifier checks proof mathematically -> grants access/discount.

== What to research
1. Circom - a DSL(Doman-specific language) for writing ZK(Zero-Knowledge) circuits. Circom files compile to WASM, C++, and JS. Those files will be needed to create proofs. I think we will have one circuit per feature. So for student verification 1 circuit. For age verification another circuit. I suggest going through #link("https://docs.circom.io/")[circom documentation].

2. Snarkjs - a JS library for creating and verifying proofs. I will also have to research this one a bit deeper.
3. Arkworks - a Rust library that can also create proofs and verify them. But this is for server-side since rust doesn't run in browsers.

4. W3C Verifiable Credential - a credential format also research what "did"(Decentralized identifier) is. Here's #link("https://www.w3.org/TR/vc-data-model-2.0/")[the documentation]. But I think it's better to let the AI explain it to you.
5. Deployment. The easiest setup would be AWS ECS + Fargate. Use AWS KMS to manage keys.
6. Infrastructure: Terraform/Opentofu.
7. CI/CD: Github actions. Duh we are "forced" to use github.
8. Language + Framework to implement the domain logic. I will probably create a poll.
9. Frontent will probably be written using some JS framework(but we will 100% use typescript). We should also decide on that. Also I am still not sure about how the wallet would work. I don't know whether it should be a browser extension or a separate website.
10. For signing the credentials, we will probably use Ed25519.
11. OAuth/OIDC how to do authentication via university's IDP(Identity Provider). We will have to figure out how to do it. If it doesn't work we will have to create a dummy idp(also verify if it is feasible).

==  THREEEEEE MAIN QUESTIONS
1. Is it useful/usable? It will be using the interface we build whether it is a browser extension or a website.
2. Is it valuable? I think so. I must not be the only one who passed on gemini and cursor deals because they asked for an ID.
3. Is it feasible? Creating one service in one semester? Seems feasible to me.
