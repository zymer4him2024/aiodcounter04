# MERCADO PAGO INTEGRATION - COMPLETE SETUP GUIDE

## 🇧🇷 PHASE 1: PAYMENT SYSTEM WITH MERCADO PAGO

Complete integration with test mode → production switch built-in.

---

## 📋 TABLE OF CONTENTS

1. [Setup Mercado Pago Account](#setup)
2. [Environment Configuration](#environment)
3. [Backend Integration](#backend)
4. [Frontend Components](#frontend)
5. [Testing Guide](#testing)
6. [Production Switch](#production)

---

## 🎯 SETUP MERCADO PAGO ACCOUNT {#setup}

### Step 1: Create Account

```
1. Go to: https://www.mercadopago.com.br
2. Click "Criar conta grátis"
3. Sign up with email
4. Verify email address
```

### Step 2: Access Developer Panel

```
1. Login to Mercado Pago
2. Go to: https://www.mercadopago.com.br/developers
3. Click "Minhas integrações"
4. Click "Criar aplicação"
5. Name: "AIOD Camera Counter"
6. Select: "Pagamentos online e presenciais"
```

### Step 3: Get Test Credentials

```
Navigation:
Suas integrações → [Your App] → Credenciais

You'll see:

┌─────────────────────────────────────────┐
│ Modo de Testes                          │
├─────────────────────────────────────────┤
│ Public Key:                             │
│ TEST-abc123-xxx-yyy-zzz-pqr            │
│                                         │
│ Access Token:                           │
│ TEST-1234567890-abcdef-ghijkl          │
└─────────────────────────────────────────┘

⚠️ Save these! We'll use them next.
```

---

## ⚙️ ENVIRONMENT CONFIGURATION {#environment}

### Firebase Functions Config

```bash
cd /Users/shawnshlee/1_CursorAI/1_aiodcounter04/ai-od-counter-multitenant

# Set test credentials
firebase functions:config:set \
  mercadopago.mode="test" \
  mercadopago.test_access_token="TEST-your-token-here" \
  mercadopago.test_public_key="TEST-your-key-here" \
  mercadopago.prod_access_token="APP_USR-production-later" \
  mercadopago.prod_public_key="APP_USR-production-later"

# Verify
firebase functions:config:get
```

### Environment Variables File

Create `.env` in functions folder:

```bash
# functions/.env

# Mercado Pago Configuration
MERCADO_PAGO_MODE=test
# test = usar credenciais de teste
# production = usar credenciais de produção

# Test Credentials
MERCADO_PAGO_TEST_ACCESS_TOKEN=TEST-your-token
MERCADO_PAGO_TEST_PUBLIC_KEY=TEST-your-key

# Production Credentials (set later)
MERCADO_PAGO_PROD_ACCESS_TOKEN=APP_USR-xxx
MERCADO_PAGO_PROD_PUBLIC_KEY=APP_USR-xxx

# Webhook Configuration
MERCADO_PAGO_WEBHOOK_URL=https://us-central1-aiodcouter04.cloudfunctions.net/mercadoPagoWebhook

# App Configuration
APP_URL=https://aiodcounter04-superadmin.web.app
```

---

## 🏗️ BACKEND INTEGRATION {#backend}

### Install Dependencies

```bash
cd functions/
npm install mercadopago
npm install @types/mercadopago --save-dev
```

### File Structure

```
functions/
├── src/
│   ├── mercadopago/
│   │   ├── config.ts           # Configuration
│   │   ├── payments.ts         # Payment creation
│   │   ├── subscriptions.ts    # Subscription management
│   │   ├── webhooks.ts         # Webhook handlers
│   │   └── index.ts            # Exports
│   ├── utils/
│   │   ├── featureGate.ts      # Feature access control
│   │   └── emailService.ts     # Email notifications
│   └── index.ts                # Main entry point
└── package.json
```

### Config File: `functions/src/mercadopago/config.ts`

```typescript
import * as functions from 'firebase-functions';

interface MercadoPagoConfig {
  mode: 'test' | 'production';
  accessToken: string;
  publicKey: string;
  webhookUrl: string;
}

export const getMercadoPagoConfig = (): MercadoPagoConfig => {
  const config = functions.config();
  const mode = config.mercadopago?.mode || 'test';
  
  // Automatically select credentials based on mode
  const accessToken = mode === 'test' 
    ? config.mercadopago?.test_access_token
    : config.mercadopago?.prod_access_token;
    
  const publicKey = mode === 'test'
    ? config.mercadopago?.test_public_key
    : config.mercadopago?.prod_public_key;
  
  if (!accessToken || !publicKey) {
    throw new Error(`Mercado Pago ${mode} credentials not configured`);
  }
  
  return {
    mode,
    accessToken,
    publicKey,
    webhookUrl: config.mercadopago?.webhook_url
  };
};

// Easy switch between test and production
export const isTestMode = (): boolean => {
  return getMercadoPagoConfig().mode === 'test';
};

// Get Mercado Pago client
import { MercadoPagoConfig as MPConfig, Payment, Preference } from 'mercadopago';

export const getMercadoPagoClient = () => {
  const config = getMercadoPagoConfig();
  
  const client = new MPConfig({
    accessToken: config.accessToken,
    options: {
      timeout: 5000,
      idempotencyKey: 'abc'
    }
  });
  
  return client;
};

export const SUBSCRIPTION_TIERS = {
  basico: {
    id: 'tier_basico',
    name: 'Básico',
    price: 495, // R$ 495,00
    features: [
      'Contagem diária total',
      'Mix veículos vs. pedestres',
      'Gráficos básicos (7 dias)',
      'Suporte por email',
      'Exportar CSV'
    ],
    limits: {
      cameras: 3,
      dataRetentionDays: 30,
      reportsPerMonth: 10,
      exportFormats: ['csv']
    }
  },
  
  profissional: {
    id: 'tier_profissional',
    name: 'Profissional',
    price: 1495, // R$ 1.495,00
    features: [
      'Tudo do Básico',
      'Análise por hora',
      'Análise por tipo de veículo',
      'Relatórios semanais e mensais',
      'Identificação de horários de pico',
      'Exportar PDF e Excel',
      'Até 10 câmeras',
      'Suporte prioritário'
    ],
    limits: {
      cameras: 10,
      dataRetentionDays: 90,
      reportsPerMonth: 50,
      exportFormats: ['csv', 'pdf', 'xlsx']
    }
  },
  
  empresarial: {
    id: 'tier_empresarial',
    name: 'Empresarial',
    price: 4995, // R$ 4.995,00
    features: [
      'Tudo do Profissional',
      'Dashboard em tempo real',
      'Análise comparativa',
      'Correlação com clima',
      'Portais para clientes',
      'Acesso à API REST',
      'Marca branca disponível',
      'Câmeras ilimitadas',
      'Suporte dedicado'
    ],
    limits: {
      cameras: -1, // unlimited
      dataRetentionDays: 365,
      reportsPerMonth: -1, // unlimited
      exportFormats: ['csv', 'pdf', 'xlsx', 'json'],
      apiAccess: true,
      apiCallsPerMonth: 100000
    }
  }
};
```

---

## 💳 PAYMENT CREATION {#payments}

### File: `functions/src/mercadopago/payments.ts`

```typescript
import { Payment, PaymentCreateRequest } from 'mercadopago';
import { getMercadoPagoClient, SUBSCRIPTION_TIERS, isTestMode } from './config';
import * as admin from 'firebase-admin';

interface CreatePixPaymentParams {
  userId: string;
  tier: 'basico' | 'profissional' | 'empresarial';
  email: string;
  cpfCnpj: string;
  firstName: string;
  lastName: string;
}

export const createPixPayment = async (params: CreatePixPaymentParams) => {
  const client = getMercadoPagoClient();
  const payment = new Payment(client);
  
  const tier = SUBSCRIPTION_TIERS[params.tier];
  const amount = tier.price;
  
  const paymentData: PaymentCreateRequest = {
    body: {
      transaction_amount: amount,
      description: `Assinatura ${tier.name} - AIOD Counter`,
      payment_method_id: 'pix',
      payer: {
        email: params.email,
        first_name: params.firstName,
        last_name: params.lastName,
        identification: {
          type: params.cpfCnpj.length === 14 ? 'CPF' : 'CNPJ',
          number: params.cpfCnpj.replace(/[^\d]/g, '')
        }
      },
      notification_url: `${process.env.WEBHOOK_URL}/mercadopago`,
      metadata: {
        user_id: params.userId,
        tier: params.tier,
        environment: isTestMode() ? 'test' : 'production'
      }
    }
  };
  
  try {
    const response = await payment.create(paymentData);
    
    // Store payment request in Firestore
    const db = admin.firestore();
    await db.collection('payment_requests').doc(response.id!.toString()).set({
      userId: params.userId,
      tier: params.tier,
      amount: amount,
      method: 'pix',
      status: 'pending',
      mercadoPagoId: response.id,
      pixQrCode: response.point_of_interaction?.transaction_data?.qr_code,
      pixQrCodeBase64: response.point_of_interaction?.transaction_data?.qr_code_base64,
      expiresAt: admin.firestore.Timestamp.fromDate(
        new Date(Date.now() + 30 * 60 * 1000) // 30 minutes
      ),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      isTest: isTestMode()
    });
    
    return {
      paymentId: response.id,
      qrCode: response.point_of_interaction?.transaction_data?.qr_code,
      qrCodeBase64: response.point_of_interaction?.transaction_data?.qr_code_base64,
      amount: amount,
      expiresIn: 30 * 60 // 30 minutes in seconds
    };
    
  } catch (error) {
    console.error('Error creating Pix payment:', error);
    throw new Error('Failed to create payment');
  }
};

// Get payment status
export const getPaymentStatus = async (paymentId: string) => {
  const client = getMercadoPagoClient();
  const payment = new Payment(client);
  
  try {
    const response = await payment.get({ id: paymentId });
    return {
      status: response.status,
      statusDetail: response.status_detail,
      amount: response.transaction_amount,
      dateApproved: response.date_approved
    };
  } catch (error) {
    console.error('Error getting payment status:', error);
    throw error;
  }
};
```

---

## 🔔 WEBHOOK HANDLER {#webhooks}

### File: `functions/src/mercadopago/webhooks.ts`

```typescript
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { getPaymentStatus } from './payments';
import { activateSubscription } from './subscriptions';

export const mercadoPagoWebhook = functions.https.onRequest(async (req, res) => {
  // Mercado Pago sends notifications as GET or POST
  const notification = req.method === 'GET' ? req.query : req.body;
  
  console.log('Mercado Pago webhook received:', notification);
  
  // Return 200 immediately to acknowledge receipt
  res.status(200).send('OK');
  
  try {
    // Extract payment info
    const { type, data } = notification;
    
    if (type === 'payment') {
      const paymentId = data.id;
      
      // Get payment details
      const paymentStatus = await getPaymentStatus(paymentId);
      
      if (paymentStatus.status === 'approved') {
        // Payment confirmed! Activate subscription
        const db = admin.firestore();
        const paymentDoc = await db.collection('payment_requests')
          .doc(paymentId)
          .get();
        
        if (paymentDoc.exists) {
          const paymentData = paymentDoc.data();
          
          // Activate subscription
          await activateSubscription({
            userId: paymentData!.userId,
            tier: paymentData!.tier,
            paymentId: paymentId,
            amount: paymentData!.amount
          });
          
          // Update payment request
          await paymentDoc.ref.update({
            status: 'paid',
            paidAt: admin.firestore.FieldValue.serverTimestamp(),
            mercadoPagoStatus: paymentStatus.status
          });
          
          console.log(`Subscription activated for user ${paymentData!.userId}`);
        }
      }
    }
    
  } catch (error) {
    console.error('Webhook processing error:', error);
    // Don't throw - already sent 200 to Mercado Pago
  }
});
```

---

## 📝 SUBSCRIPTION MANAGEMENT {#subscriptions}

### File: `functions/src/mercadopago/subscriptions.ts`

```typescript
import * as admin from 'firebase-admin';
import { SUBSCRIPTION_TIERS } from './config';

interface ActivateSubscriptionParams {
  userId: string;
  tier: 'basico' | 'profissional' | 'empresarial';
  paymentId: string;
  amount: number;
}

export const activateSubscription = async (params: ActivateSubscriptionParams) => {
  const db = admin.firestore();
  const tier = SUBSCRIPTION_TIERS[params.tier];
  
  const now = admin.firestore.Timestamp.now();
  const oneMonthLater = new Date();
  oneMonthLater.setMonth(oneMonthLater.getMonth() + 1);
  
  const subscriptionData = {
    tier: params.tier,
    status: 'active',
    paymentMethod: 'pix',
    currentPeriodStart: now,
    currentPeriodEnd: admin.firestore.Timestamp.fromDate(oneMonthLater),
    nextBillingDate: admin.firestore.Timestamp.fromDate(oneMonthLater),
    lastPaymentDate: now,
    lastPaymentId: params.paymentId,
    lastPaymentAmount: params.amount,
    paymentStatus: 'paid'
  };
  
  // Update user document
  await db.collection('users').doc(params.userId).update({
    subscription: subscriptionData,
    limits: tier.limits,
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  });
  
  // Create subscription record
  await db.collection('subscriptions').add({
    userId: params.userId,
    tier: params.tier,
    status: 'active',
    amount: params.amount,
    paymentId: params.paymentId,
    startDate: now,
    endDate: admin.firestore.Timestamp.fromDate(oneMonthLater),
    createdAt: admin.firestore.FieldValue.serverTimestamp()
  });
  
  // Create invoice
  await db.collection('invoices').add({
    userId: params.userId,
    amount: params.amount,
    tier: params.tier,
    status: 'paid',
    paymentMethod: 'pix',
    paymentId: params.paymentId,
    issuedDate: now,
    paidDate: now,
    periodStart: now,
    periodEnd: admin.firestore.Timestamp.fromDate(oneMonthLater)
  });
  
  console.log(`Subscription activated: ${params.userId} - ${params.tier}`);
  
  // TODO: Send welcome email
};

// Check subscription status
export const checkSubscriptionStatus = async (userId: string) => {
  const db = admin.firestore();
  const userDoc = await db.collection('users').doc(userId).get();
  
  if (!userDoc.exists) {
    return { active: false, tier: null };
  }
  
  const subscription = userDoc.data()?.subscription;
  
  if (!subscription) {
    return { active: false, tier: null };
  }
  
  const now = new Date();
  const periodEnd = subscription.currentPeriodEnd.toDate();
  
  return {
    active: subscription.status === 'active' && now < periodEnd,
    tier: subscription.tier,
    status: subscription.status,
    expiresAt: periodEnd
  };
};
```

---

## 🎨 FRONTEND PRICING PAGE {#frontend}

### File: `web-dashboard/src/components/Pricing.jsx`

```jsx
import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';

const TIERS = {
  basico: {
    name: 'Básico',
    price: 495,
    features: [
      'Contagem diária total',
      'Mix veículos vs. pedestres',
      'Gráficos básicos (7 dias)',
      'Suporte por email',
      'Exportar CSV',
      'Até 3 câmeras'
    ]
  },
  profissional: {
    name: 'Profissional',
    price: 1495,
    popular: true,
    features: [
      'Tudo do Básico',
      'Análise por hora',
      'Análise por tipo de veículo',
      'Relatórios semanais e mensais',
      'Horários de pico',
      'Exportar PDF e Excel',
      'Até 10 câmeras',
      'Suporte prioritário'
    ]
  },
  empresarial: {
    name: 'Empresarial',
    price: 4995,
    features: [
      'Tudo do Profissional',
      'Dashboard em tempo real',
      'Análise comparativa',
      'Correlação com clima',
      'Portais para clientes',
      'API REST',
      'Marca branca',
      'Câmeras ilimitadas',
      'Suporte dedicado'
    ]
  }
};

const Pricing = () => {
  const navigate = useNavigate();
  
  const handleSelectPlan = (tier) => {
    navigate(`/checkout/${tier}`);
  };
  
  return (
    <div className="min-h-screen bg-gray-50 py-12 px-4">
      <div className="max-w-7xl mx-auto">
        <div className="text-center mb-12">
          <h1 className="text-4xl font-bold text-gray-900 mb-4">
            Escolha seu Plano
          </h1>
          <p className="text-xl text-gray-600">
            Comece com 30 dias de garantia. Cancele quando quiser.
          </p>
        </div>
        
        <div className="grid md:grid-cols-3 gap-8">
          {Object.entries(TIERS).map(([key, tier]) => (
            <div
              key={key}
              className={`bg-white rounded-2xl shadow-xl overflow-hidden ${
                tier.popular ? 'ring-4 ring-blue-500' : ''
              }`}
            >
              {tier.popular && (
                <div className="bg-blue-500 text-white text-center py-2 text-sm font-semibold">
                  MAIS POPULAR
                </div>
              )}
              
              <div className="p-8">
                <h3 className="text-2xl font-bold text-gray-900 mb-2">
                  {tier.name}
                </h3>
                
                <div className="mb-6">
                  <span className="text-4xl font-bold text-gray-900">
                    R$ {tier.price}
                  </span>
                  <span className="text-gray-600">/mês</span>
                </div>
                
                <button
                  onClick={() => handleSelectPlan(key)}
                  className={`w-full py-3 px-6 rounded-lg font-semibold transition ${
                    tier.popular
                      ? 'bg-blue-600 text-white hover:bg-blue-700'
                      : 'bg-gray-100 text-gray-900 hover:bg-gray-200'
                  }`}
                >
                  Começar Agora
                </button>
                
                <ul className="mt-8 space-y-3">
                  {tier.features.map((feature, idx) => (
                    <li key={idx} className="flex items-start">
                      <svg
                        className="w-5 h-5 text-green-500 mr-3 flex-shrink-0 mt-0.5"
                        fill="currentColor"
                        viewBox="0 0 20 20"
                      >
                        <path
                          fillRule="evenodd"
                          d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z"
                          clipRule="evenodd"
                        />
                      </svg>
                      <span className="text-gray-700">{feature}</span>
                    </li>
                  ))}
                </ul>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
};

export default Pricing;
```

---

## 🧪 TESTING GUIDE {#testing}

### Test Pix Payment Flow

1. **Start local development:**
```bash
firebase emulators:start
```

2. **Navigate to pricing page:**
```
http://localhost:3000/pricing
```

3. **Select a plan**
- Click "Começar Agora"
- Enter CPF: 123.456.789-00 (test CPF)
- Click "Gerar QR Code Pix"

4. **Simulate payment:**
- Go to Mercado Pago developer panel
- Find your test payment
- Click "Aprovar Pagamento"

5. **Verify webhook:**
- Check Firebase Functions logs
- Verify subscription activated in Firestore

### Test Data

```javascript
// Valid test CPF
CPF: 123.456.789-00

// Test user
Email: teste@example.com
Name: João Silva
```

---

## 🚀 PRODUCTION SWITCH {#production}

### When Ready for Production:

**Step 1: Complete Mercado Pago Verification**
```
1. Submit business documents (CNPJ)
2. Verify bank account
3. Complete identity verification
4. Get production credentials
```

**Step 2: Update Firebase Config**
```bash
firebase functions:config:set \
  mercadopago.mode="production" \
  mercadopago.prod_access_token="APP_USR-your-prod-token" \
  mercadopago.prod_public_key="APP_USR-your-prod-key"
  
firebase deploy --only functions
```

**Step 3: Update Environment**
```bash
# Change in .env
MERCADO_PAGO_MODE=production
```

**That's it!** The code automatically switches between test/production based on the `mode` setting.

---

## ✅ CHECKLIST

### Test Mode Setup
- [ ] Mercado Pago account created
- [ ] Test credentials obtained
- [ ] Firebase config set
- [ ] Dependencies installed
- [ ] Functions deployed
- [ ] Pricing page working
- [ ] Test payment successful
- [ ] Webhook received
- [ ] Subscription activated

### Production Ready
- [ ] Business verification complete
- [ ] Production credentials obtained
- [ ] Config updated to production
- [ ] Functions redeployed
- [ ] Real payment tested
- [ ] Invoicing system working
- [ ] Monitoring enabled

---

## 📞 SUPPORT

If you need help:
- Mercado Pago Docs: https://www.mercadopago.com.br/developers
- Support: https://www.mercadopago.com.br/ajuda

---

**NEXT: We'll create the checkout flow and Pix QR code display!** 🚀
