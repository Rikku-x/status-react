(ns status-im.ui.screens.wallet.core
  (:require [taoensso.timbre :as log]))

(defonce loaded? (atom false))

(defonce module (atom {}))

(defn load-wallet-module []
  (when-not @loaded?
    (log/debug :load-wallet-module)
    (when-not goog/DEBUG
      (js/eval (js/require "status-modules/wallet.js"))
      (reset! module
              {:collectibles             (resolve 'status-im.ui.screens.wallet.collectibles.views/collectibles-list)
               :contact-code             (resolve 'status-im.ui.screens.wallet.components.views/contact-code)
               :recent-recipients        (resolve 'status-im.ui.screens.wallet.components.views/recent-recipients)
               :recipient-qr-code        (resolve 'status-im.ui.screens.wallet.components.views/recipient-qr-code)
               :send-assets              (resolve 'status-im.ui.screens.wallet.components.views/send-assets)
               :request-assets           (resolve 'status-im.ui.screens.wallet.components.views/request-assets)
               :wallet                   (resolve 'status-im.ui.screens.wallet.main.views/wallet)
               :onboarding               (resolve 'status-im.ui.screens.wallet.onboarding.views/screen)
               :onboarding-modal         (resolve 'status-im.ui.screens.wallet.onboarding.views/modal)
               :request-transaction      (resolve 'status-im.ui.screens.wallet.request.views/request-transaction)
               :send-transaction-request (resolve 'status-im.ui.screens.wallet.request.views/send-transaction-request)
               :send-transaction-modal   (resolve 'status-im.ui.screens.wallet.send.views/send-transaction-modal)
               :send-transaction         (resolve 'status-im.ui.screens.wallet.send.views/send-transaction)
               :settings-hook            (resolve 'status-im.ui.screens.wallet.settings.views/settings-hook)
               :manage-assets            (resolve 'status-im.ui.screens.wallet.settings.views/manage-assets)
               :sign-message-modal       (resolve 'status-im.ui.screens.wallet.sign-message.views/sign-message-modal)
               :transaction-fee          (resolve 'status-im.ui.screens.wallet.transaction-fee.views/transaction-fee)
               :transaction-sent-modal   (resolve 'status-im.ui.screens.wallet.transaction-sent.views/transaction-sent-modal)
               :transaction-sent         (resolve 'status-im.ui.screens.wallet.transaction-sent.views/transaction-sent)
               :transactions             (resolve 'status-im.ui.screens.wallet.transactions.views/transactions)
               :transaction-details      (resolve 'status-im.ui.screens.wallet.transactions.views/transaction-details)
               :filter-history           (resolve 'status-im.ui.screens.wallet.transactions.views/filter-history)
               :add-custom-token         (resolve 'status-im.ui.screens.wallet.custom-tokens.views/add-custom-token)
               :custom-token-details     (resolve 'status-im.ui.screens.wallet.custom-tokens.views/custom-token-details)
               :separator                (resolve 'status-im.ui.screens.wallet.components.views/separator)}))
    (reset! loaded? true)
    (log/debug :wallet-module-loaded)))

(defn get-sym [sym]
  (load-wallet-module)
  (get @module sym))

(defn collectibles []
  [(get-sym :collectibles)])

(defn contact-code []
  [(get-sym :contact-code)])

(defn recent-recipients []
  [(get-sym :recent-recipients)])

(defn recipient-qr-code []
  [(get-sym :recipient-qr-code)])

(defn send-assets []
  [(get-sym :send-assets)])

(defn request-assets []
  [(get-sym :request-assets)])

(defn wallet []
  [(get-sym :wallet)])

(defn onboarding []
  [(get-sym :onboarding)])

(defn onboarding-modal []
  [(get-sym :onboarding-modal)])

(defn request-transaction []
  [(get-sym :request-transaction)])

(defn send-transaction-request []
  [(get-sym :send-transaction-request)])

(defn send-transaction-modal []
  [(get-sym :send-transaction-modal)])

(defn send-transaction []
  [(get-sym :send-transaction)])

(defn settings-hook []
  [(get-sym :settings-hook)])

(defn manage-assets []
  [(get-sym :manage-assets)])

(defn sign-message-modal []
  [(get-sym :sign-message-modal)])

(defn transaction-fee []
  [(get-sym :transaction-fee)])

(defn transaction-sent-modal []
  [(get-sym :transaction-sent-modal)])

(defn transaction-sent []
  [(get-sym :transaction-sent)])

(defn transactions []
  [(get-sym :transactions)])

(defn transaction-details []
  [(get-sym :transaction-details)])

(defn filter-history []
  [(get-sym :filter-history)])

(defn add-custom-token []
  [(get-sym :add-custom-token)])

(defn custom-token-details []
  [(get-sym :custom-token-details)])

(defn separator []
  [(get-sym :separator)])
