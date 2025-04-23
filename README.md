# TutorChain: A Tokenized Peer-to-Peer Tutoring Marketplace

## Overview

**TutorChain** is a decentralized tutoring marketplace built on the **Stacks blockchain**, enabling direct interaction between students and tutors without intermediaries. Through smart contracts, it ensures secure payments, transparent reputations, and incentives for quality tutoring.

---

## Problem It Solves

Traditional tutoring platforms are riddled with problems:

- **High Platform Fees**: Centralized apps charge up to 50% commission.
- **Lack of Transparency**: Ratings can be manipulated, and credentials are hard to verify.
- **Delayed Payments**: Payouts are slow and prone to disputes.
- **Misaligned Incentives**: Platforms focus on profit—not learning outcomes.

---

## The TutorChain Approach

TutorChain uses smart contracts to directly align tutor performance with reward, solving the problems above via:

- **Direct student-tutor payments**
- **Verifiable tutor performance**
- **Secure session-based escrow**
- **Stake-based reputation signals**

---

## 🔑 Core Features

### ✅ Tutor & Student Registration
- Tutors register with bio, hourly rate, and subjects.
- Students simply register to access the platform.

### ✅ Session Booking & Escrow
- Sessions are scheduled by students.
- Payment is held in **escrow** via smart contract.
- Tutors initiate and complete sessions.
- Students confirm and release payment.
- A small **5% platform fee** is deducted automatically.

### ✅ Reputation & Ratings
- Students rate tutors after each session.
- Ratings are stored on-chain for future tutor discovery.

### ✅ Staking & Expertise
- Tutors **stake tokens** as proof of commitment.
- Expertise points are awarded in specific subjects after sessions.
- Staked amount and expertise scores build credibility.

---

## 💡 Contract Structure

The project consists of two main smart contracts:

### 1. `core.clar` - Core Tutoring Logic
- Handles registration, session lifecycle, rating, and payments.
- Manages tutor profiles, subject selection, and reputation.

### 2. `token.clar` - TutorChain Token
- Implements SIP-010 fungible token logic.
- Supports staking and expertise tracking.
- Enables token-based incentives.

---

## 🛠️ Technical Breakdown

### Core Data Models
- **Users**: Map principal to role (student/tutor).
- **Profiles**: Store tutor bios, rates, and subjects.
- **Sessions**: Store session status, tutor/student, payment, and ratings.
- **Stakes**: Manage token stakes for each tutor.
- **Expertise**: Track subject-specific tutor skills.

### Core Functions

#### User Registration
```clarity
(register-as-student)
(register-as-tutor (bio (string-utf8 500)) (hourly-rate uint) (subjects (list 5 uint)))
```

#### Session Lifecycle
```clarity
(schedule-session (tutor principal) (subject-id uint) (scheduled-start uint) (duration-minutes uint) (token <ft-trait>))
(start-session (session-id uint))
(complete-session (session-id uint))
(release-payment (session-id uint) (rating uint) (token <ft-trait>))
(dispute-session (session-id uint))
```

#### Queries
```clarity
(get-tutor-profile (tutor principal))
(get-tutor-rating (tutor principal))
(get-session (session-id uint))
```

---

### Token Contract Functions

#### Staking
```clarity
(stake (amount uint))
(unstake (amount uint))
(get-stake (tutor principal))
```

#### Expertise Tracking
```clarity
(award-expertise (tutor principal) (subject-id uint) (points uint))
(get-expertise (tutor principal) (subject-id uint))
```

---

## 🔁 User Journey

1. **Tutor Onboarding**
   - Registers with subjects, bio, and rate.
   - Stakes tokens for credibility.

2. **Student Onboarding**
   - Registers and browses tutors by subject and rating.

3. **Session Flow**
   - Student schedules session → payment in escrow.
   - Tutor starts session → marks complete.
   - Student confirms → rates tutor → funds released.

4. **Dispute Resolution**
   - Student can open a dispute before payment release.

---

## 🛡️ Security Highlights

- **Escrow Payments**: Held securely in contract until confirmation.
- **Authorization Checks**: Only correct roles can perform certain actions.
- **Dispute Protection**: Students can dispute before releasing funds.
- **Staking Mechanism**: Reduces likelihood of spam/fraud tutors.

---

## 🧪 Getting Started Locally

### Prerequisites

- Install [Clarinet](https://github.com/hirosystems/clarinet)
- Set up [Stacks Wallet](https://www.hiro.so/wallet)

### Development Setup

```bash
git clone https://github.com/yourusername/tutorchain.git
cd tutorchain
npm install
clarinet test
clarinet deploy --testnet
```

---

## 🔮 Future Upgrades

- **Subject-specific NFTs** for tutor certifications
- **AI-based Tutor Matching**
- **Decentralized Dispute Arbitration**
- **Token-weighted Voting for Governance**
- **Multi-Session Bookings**

---

## ⚡ Why TutorChain?

- Solves real-world tutoring market pain points
- Uses blockchain to build **trust**, not just tech
- Designed for **scalability and transparency**
- Empowers both students and tutors through incentives

---

## 📄 License

Licensed under the **MIT License**. See `LICENSE` for full details.
