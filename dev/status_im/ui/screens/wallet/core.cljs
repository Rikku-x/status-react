(ns status-im.ui.screens.wallet.core
  (:require
   status-im.ui.screens.wallet.collectibles.events
   status-im.ui.screens.wallet.send.events
   status-im.ui.screens.wallet.request.events
   status-im.ui.screens.wallet.collectibles.cryptokitties.events
   status-im.ui.screens.wallet.collectibles.cryptostrikers.events
   status-im.ui.screens.wallet.collectibles.etheremon.events
   status-im.ui.screens.wallet.collectibles.superrare.events
   status-im.ui.screens.wallet.collectibles.kudos.events
   status-im.ui.screens.wallet.navigation
   [status-im.ui.screens.wallet.collectibles.views :as collectibles]
   [status-im.ui.screens.wallet.main.views :as main]
   [status-im.ui.screens.wallet.onboarding.views :as onboarding]
   [status-im.ui.screens.wallet.request.views :as request]
   [status-im.ui.screens.wallet.send.views :as send]
   [status-im.ui.screens.wallet.settings.views :as settings]
   [status-im.ui.screens.wallet.sign-message.views :as sign-message]
   [status-im.ui.screens.wallet.transaction-fee.views :as transaction-fee]
   [status-im.ui.screens.wallet.transaction-sent.views :as transaction-sent]
   [status-im.ui.screens.wallet.transactions.views :as transactions]
   [status-im.ui.screens.wallet.components.views :as components]
   [status-im.ui.screens.wallet.custom-tokens.views :as custom-tokens]))

(defn load-wallet-module [])

(defn collectibles []
  [collectibles/collectibles-list])

(defn contact-code []
  [components/contact-code])

(defn recent-recipients []
  [components/recent-recipients])

(defn recipient-qr-code []
  [components/recipient-qr-code])

(defn send-assets []
  [components/send-assets])

(defn request-assets []
  [components/request-assets])

(defn wallet []
  [main/wallet])

(defn onboarding []
  [onboarding/screen])

(defn onboarding-modal []
  [onboarding/modal])

(defn request-transaction []
  [request/request-transaction])

(defn send-transaction-request []
  [request/send-transaction-request])

(defn send-transaction-modal []
  [send/send-transaction-modal])

(defn send-transaction []
  [send/send-transaction])

(defn settings-hook []
  [settings/settings-hook])

(defn manage-assets []
  [settings/manage-assets])

(defn sign-message-modal []
  [sign-message/sign-message-modal])

(defn transaction-fee []
  [transaction-fee/transaction-fee])

(defn transaction-sent-modal []
  [transaction-sent/transaction-sent-modal])

(defn transaction-sent []
  [transaction-sent/transaction-sent])

(defn transactions []
  [transactions/transactions])

(defn transaction-details []
  [transactions/transaction-details])

(defn filter-history []
  [transactions/filter-history])

(defn add-custom-token []
  [custom-tokens/add-custom-token])

(defn custom-token-details []
  [custom-tokens/custom-token-details])

(defn separator []
  [components/separator])
