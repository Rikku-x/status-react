(ns status-im.i18n
  (:require-macros [status-im.i18n :as i18n])
  (:require
   [cljs.spec.alpha :as spec]
   [status-im.react-native.js-dependencies :as rn-dependencies]
   [clojure.string :as string]
   [clojure.set :as set]
   [status-im.utils.types :as types]))

(set! (.-locale rn-dependencies/i18n) (.-language rn-dependencies/react-native-languages))
(set! (.-fallbacks rn-dependencies/i18n) true)
(set! (.-defaultSeparator rn-dependencies/i18n) "/")

;; translations
(def translations-by-locale
  (->> (i18n/translations [:en :es_419 :fa :ko :ms :pl :ru :zh_Hans_CN])
       (map (fn [[k t]]
              (let [k' (-> (name k)
                           (string/replace "_" "-")
                           keyword)]
                [k' (types/json->clj t)])))
       (into {})))

;; english as source of truth
(def labels (set (keys (:en translations-by-locale))))

(spec/def ::label labels)
(spec/def ::labels (spec/coll-of ::label :kind set? :into #{}))

(defn labels-for-all-locales []
  (->> translations-by-locale
       (mapcat #(-> % val keys))
       set))

;; checkpoints

;; Checkpoints specify milestones for locales.
;;
;; With milestones we can ensure that expected supported languages
;; are actually supported, and visualize the translation state for
;; the rest of locales according to these milestones.
;;
;; Checkpoints are defined by indicating the labels that need to be present
;; in a locale to achieve that checkpoint.
;;
;; We need to define the checkpoint that needs to be achieved for
;; a locale to be considered supported. This is why as we develop
;; we add translations, so we need to be defining a new target
;; for supported languages to achieve.
;;
;; Checkpoints are only used in dev and test. In dev when we want to
;; manually check the state of checkpoints for locales, and in test
;; to automatically check supported locales against the target checkpoint.

(spec/def ::checkpoint.id keyword?)
(spec/def ::checkpoint-defs (spec/map-of ::checkpoint.id ::labels))

;; We define here the labels for the first specified checkpoint.
(def checkpoint-0-9-12-labels
  #{:validation-amount-invalid-number :transaction-details :confirm :description
    :phone-national :amount :open :close-app-title :members-active :chat-name
    :phew-here-is-your-passphrase :public-group-topic :debug-enabled
    :chat-settings :offline :update-status :invited :chat-send-eth :address
    :new-public-group-chat :datetime-hour :wallet-settings
    :datetime-ago-format :close-app-button :block :camera-access-error
    :wallet-invalid-address :wallet-invalid-address-checksum :address-explication :remove
    :transactions-delete-content :transactions-unsigned-empty
    :transaction-moved-text :add-members :sign-later-title
    :yes :dapps :popular-tags :network-settings :twelve-words-in-correct-order
    :transaction-moved-title :photos-access-error :hash
    :removed-from-chat :done :remove-from-contacts :delete-chat :new-group-chat
    :edit-chats :wallet :wallet-exchange :wallet-request :sign-in
    :datetime-yesterday :create-new-account :sign-in-to-status :save-password :save-password-unavailable :dapp-profile
    :sign-later-text :datetime-ago :no-hashtags-discovered-body :contacts
    :search-chat :got-it :delete-group-confirmation :public-chats
    :not-applicable :move-to-internal-failure-message :active-online
    :password :status-seen-by-everyone :edit-group :not-specified
    :delete-group :send-request :paste-json :browsing-title
    :wallet-add-asset :reorder-groups :transactions-history-empty :discover
    :browsing-cancel :faucet-success :intro-status :name :gas-price
    :view-transaction-details :wallet-error
    :validation-amount-is-too-precise :copy-transaction-hash :unknown-address
    :received-invitation :show-qr :edit-network-config :connect
    :choose-from-contacts :edit :wallet-address-from-clipboard
    :account-generation-message :remove-network :no-messages :passphrase
    :recipient :members-title :new-group :suggestions-requests
    :connected :rpc-url :settings :remove-from-group :specify-rpc-url
    :transactions-sign-all :gas-limit :wallet-browse-photos
    :add-new-contact :no-statuses-discovered-body :add-json-file :delete
    :search-contacts :chats :transaction-sent :transaction :public-group-status
    :leave-chat :transactions-delete :mainnet-text :image-source-make-photo
    :chat :start-conversation :topic-format :add-new-network :save
    :enter-valid-public-key :faucet-error :all
    :confirmations-helper-text :search-for :sharing-copy-to-clipboard
    :your-wallets :sync-in-progress :enter-password
    :enter-address :switch-users :send-transaction :confirmations
    :recover-access :image-source-gallery :sync-synced
    :currency :status-pending :delete-contact :connecting-requires-login
    :no-hashtags-discovered-title :datetime-day :request-transaction
    :wallet-send :mute-notifications :scan-qr :contact-s
    :unsigned-transaction-expired :status-sending :gas-used
    :transactions-filter-type :next :recent
    :open-on-etherscan :share :status :from
    :wrong-password :search-chats :transactions-sign-later :in-contacts
    :transactions-sign :sharing-share :type-a-message
    :usd-currency :existing-networks :node-unavailable :url :shake-your-phone
    :add-network :unknown-status-go-error :contacts-group-new-chat :and-you
    :wallets :clear-history :wallet-choose-from-contacts
    :signing-phrase-description :no-contacts :here-is-your-signing-phrase
    :soon :close-app-content :status-sent :status-prompt
    :delete-contact-confirmation :datetime-today :add-a-status
    :web-view-error :notifications-title :error :transactions-sign-transaction
    :edit-contacts :more :cancel :no-statuses-found :can-not-add-yourself
    :transaction-description :add-to-contacts :available
    :paste-json-as-text :You :main-wallet :process-json :testnet-text
    :transactions :transactions-unsigned :members :intro-message1
    :public-chat-user-count :eth :transactions-history :not-implemented
    :new-contact :datetime-second :status-failed :is-typing :recover
    :suggestions-commands :nonce :new-network :contact-already-added :datetime-minute
    :browsing-open-in-ios-web-browser :browsing-open-in-android-web-browser
    :delete-group-prompt :wallet-total-value
    :wallet-insufficient-funds :edit-profile :active-unknown
    :search-tags :transaction-failed :public-key :error-processing-json
    :status-seen :transactions-filter-tokens :status-delivered :profile
    :wallet-choose-recipient :no-statuses-discovered :none :removed :empty-topic
    :no :transactions-filter-select-all :transactions-filter-title :message
    :here-is-your-passphrase :wallet-assets :image-source-title :current-network
    :left :edit-network-warning :to :data :cost-fee})

;; NOTE: the rest checkpoints are based on the previous one, defined
;;       like this:
;; (def checkpoint-2-labels (set/union checkpoint-1-labels #{:foo :bar})
;; (def checkpoint-3-labels (set/union checkpoint-2-labels #{:baz})

;; NOTE: This defines the scope of each checkpoint. To support a checkpoint,
;;       change the var `checkpoint-to-consider-locale-supported` a few lines
;;       below.
(def checkpoints-def (spec/assert ::checkpoint-defs
                                  {::checkpoint-0-9-12 checkpoint-0-9-12-labels}))
(def checkpoints (set (keys checkpoints-def)))

(spec/def ::checkpoint checkpoints)

(def checkpoint-to-consider-locale-supported ::checkpoint-0-9-12)

(defn checkpoint->labels [checkpoint]
  (get checkpoints-def checkpoint))

(defn checkpoint-val-to-compare [c]
  (-> c name (string/replace #"^.*\|" "") int))

(defn >checkpoints [& cs]
  (apply > (map checkpoint-val-to-compare cs)))

(defn labels-that-are-not-in-current-checkpoint []
  (set/difference labels (checkpoint->labels checkpoint-to-consider-locale-supported)))

;; locales

(def locales (set (keys translations-by-locale)))

(spec/def ::locale locales)
(spec/def ::locales (spec/coll-of ::locale :kind set? :into #{}))

;; NOTE: Add new locale keywords here to indicate support for them.
#_(def supported-locales (spec/assert ::locales #{:fr
                                                  :zh
                                                  :zh-hans
                                                  :zh-hans-cn
                                                  :zh-hans-mo
                                                  :zh-hant
                                                  :zh-hant-sg
                                                  :zh-hant-hk
                                                  :zh-hant-tw
                                                  :zh-hant-mo
                                                  :zh-hant-cn
                                                  :sr-RS_#Cyrl
                                                  :el
                                                  :en
                                                  :de
                                                  :lt
                                                  :sr-RS_#Latn
                                                  :sr
                                                  :sv
                                                  :ja
                                                  :uk}))
(def supported-locales (spec/assert ::locales #{:en}))

(spec/def ::supported-locale supported-locales)
(spec/def ::supported-locales (spec/coll-of ::supported-locale :kind set? :into #{}))

(defn locale->labels [locale]
  (-> translations-by-locale (get locale) keys set))

(defn locale->checkpoint [locale]
  (let [locale-labels (locale->labels locale)
        checkpoint    (->> checkpoints-def
                           (filter (fn [[checkpoint checkpoint-labels]]
                                     (set/subset? checkpoint-labels locale-labels)))
                           ffirst)]
    checkpoint))

(defn locales-with-checkpoint []
  (->> locales
       (map (fn [locale]
              [locale (locale->checkpoint locale)]))
       (into {})))

(defn locale-is-supported-based-on-translations? [locale]
  (let [c (locale->checkpoint locale)]
    (and c (or (= c checkpoint-to-consider-locale-supported)
               (>checkpoints checkpoint-to-consider-locale-supported c)))))

(defn actual-supported-locales []
  (->> locales
       (filter locale-is-supported-based-on-translations?)
       set))

(defn locales-with-full-support []
  (->> locales
       (filter (fn [locale]
                 (set/subset? labels (locale->labels locale))))
       set))

(defn supported-locales-that-are-not-considered-supported []
  (set/difference (actual-supported-locales) supported-locales))

(set! (.-translations rn-dependencies/i18n)
      (clj->js translations-by-locale))

;;:zh, :zh-hans-xx, :zh-hant-xx have been added until this bug will be fixed https://github.com/fnando/i18n-js/issues/460

(def delimeters
  "This function is a hack: mobile Safari doesn't support toLocaleString(), so we need to pass
  this map to WKWebView to make number formatting work."
  (let [n          (.toLocaleString (js/Number 1000.1))
        delimiter? (= (count n) 7)]
    (if delimiter?
      {:delimiter (subs n 1 2)
       :separator (subs n 5 6)}
      {:delimiter ""
       :separator (subs n 4 5)})))

(defn label-number [number]
  (when number
    (let [{:keys [delimiter separator]} delimeters]
      (.toNumber rn-dependencies/i18n
                 (string/replace number #"," ".")
                 (clj->js {:precision                 10
                           :strip_insignificant_zeros true
                           :delimiter                 delimiter
                           :separator                 separator})))))

(def default-option-value "<no value>")

(defn label-options [options]
  ;; i18n ignores nil value, leading to misleading messages
  (into {} (for [[k v] options] [k (or v default-option-value)])))

(defn label
  ([path] (label path {}))
  ([path options]
   (if (exists? rn-dependencies/i18n.t)
     (let [options (update options :amount label-number)]
       (.t rn-dependencies/i18n (name path) (clj->js (label-options options))))
     (name path))))

(defn label-pluralize [count path & options]
  (if (exists? rn-dependencies/i18n.t)
    (.p rn-dependencies/i18n count (name path) (clj->js options))
    (name path)))

(defn message-status-label [status]
  (->> status
       (name)
       (str "t/status-")
       (keyword)
       (label)))

(def locale
  (.-locale rn-dependencies/i18n))

(defn format-currency
  ([value currency-code]
   (format-currency value currency-code true))
  ([value currency-code currency-symbol?]
   (.addTier2Support goog/i18n.currency)
   (let [currency-code-to-nfs-map {"ZAR" goog/i18n.NumberFormatSymbols_af
                                   "ETB" goog/i18n.NumberFormatSymbols_am
                                   "EGP" goog/i18n.NumberFormatSymbols_ar
                                   "DZD" goog/i18n.NumberFormatSymbols_ar_DZ
                                   "AZN" goog/i18n.NumberFormatSymbols_az
                                   "BYN" goog/i18n.NumberFormatSymbols_be
                                   "BGN" goog/i18n.NumberFormatSymbols_bg
                                   "BDT" goog/i18n.NumberFormatSymbols_bn
                                   "EUR" goog/i18n.NumberFormatSymbols_br
                                   "BAM" goog/i18n.NumberFormatSymbols_bs
                                   "USD" goog/i18n.NumberFormatSymbols_en
                                   "CZK" goog/i18n.NumberFormatSymbols_cs
                                   "GBP" goog/i18n.NumberFormatSymbols_cy
                                   "DKK" goog/i18n.NumberFormatSymbols_da
                                   "CHF" goog/i18n.NumberFormatSymbols_de_CH
                                   "AUD" goog/i18n.NumberFormatSymbols_en_AU
                                   "CAD" goog/i18n.NumberFormatSymbols_en_CA
                                   "INR" goog/i18n.NumberFormatSymbols_en_IN
                                   "SGD" goog/i18n.NumberFormatSymbols_en_SG
                                   "MXN" goog/i18n.NumberFormatSymbols_es_419
                                   "IRR" goog/i18n.NumberFormatSymbols_fa
                                   "PHP" goog/i18n.NumberFormatSymbols_fil
                                   "ILS" goog/i18n.NumberFormatSymbols_he
                                   "HRK" goog/i18n.NumberFormatSymbols_hr
                                   "HUF" goog/i18n.NumberFormatSymbols_hu
                                   "AMD" goog/i18n.NumberFormatSymbols_hy
                                   "IDR" goog/i18n.NumberFormatSymbols_id
                                   "ISK" goog/i18n.NumberFormatSymbols_is
                                   "JPY" goog/i18n.NumberFormatSymbols_ja
                                   "GEL" goog/i18n.NumberFormatSymbols_ka
                                   "KZT" goog/i18n.NumberFormatSymbols_kk
                                   "KHR" goog/i18n.NumberFormatSymbols_km
                                   "KRW" goog/i18n.NumberFormatSymbols_ko
                                   "KGS" goog/i18n.NumberFormatSymbols_ky
                                   "CDF" goog/i18n.NumberFormatSymbols_ln
                                   "LAK" goog/i18n.NumberFormatSymbols_lo
                                   "MKD" goog/i18n.NumberFormatSymbols_mk
                                   "MNT" goog/i18n.NumberFormatSymbols_mn
                                   "MDL" goog/i18n.NumberFormatSymbols_mo
                                   "MYR" goog/i18n.NumberFormatSymbols_ms
                                   "MMK" goog/i18n.NumberFormatSymbols_my
                                   "NOK" goog/i18n.NumberFormatSymbols_nb
                                   "NPR" goog/i18n.NumberFormatSymbols_ne
                                   "PLN" goog/i18n.NumberFormatSymbols_pl
                                   "BRL" goog/i18n.NumberFormatSymbols_pt
                                   "RON" goog/i18n.NumberFormatSymbols_ro
                                   "RUB" goog/i18n.NumberFormatSymbols_ru
                                   "RSD" goog/i18n.NumberFormatSymbols_sh
                                   "LKR" goog/i18n.NumberFormatSymbols_si
                                   "ALL" goog/i18n.NumberFormatSymbols_sq
                                   "SEK" goog/i18n.NumberFormatSymbols_sv
                                   "TZS" goog/i18n.NumberFormatSymbols_sw
                                   "THB" goog/i18n.NumberFormatSymbols_th
                                   "TRY" goog/i18n.NumberFormatSymbols_tr
                                   "UAH" goog/i18n.NumberFormatSymbols_uk
                                   "PKR" goog/i18n.NumberFormatSymbols_ur
                                   "UZS" goog/i18n.NumberFormatSymbols_uz
                                   "VND" goog/i18n.NumberFormatSymbols_vi
                                   "CNY" goog/i18n.NumberFormatSymbols_zh
                                   "HKD" goog/i18n.NumberFormatSymbols_zh_HK
                                   "TWD" goog/i18n.NumberFormatSymbols_zh_TW}
         nfs                      (or (get currency-code-to-nfs-map currency-code)
                                      goog/i18n.NumberFormatSymbols_en)]
     (set! goog/i18n.NumberFormatSymbols
           (if currency-symbol?
             nfs
             (-> nfs
                 (js->clj :keywordize-keys true)
                 ;; Remove any currency symbol placeholders in the pattern
                 (update :CURRENCY_PATTERN (fn [pat]
                                             (string/replace pat #"\s*¤\s*" "")))
                 clj->js)))
     (.format
      (new goog/i18n.NumberFormat goog/i18n.NumberFormat.Format.CURRENCY currency-code)
      value))))

