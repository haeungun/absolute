diff --git a/third_party/WebKit/Source/modules/payments/PaymentDetailsModifier.idl b/third_party/WebKit/Source/modules/payments/PaymentDetailsModifier.idl
index e58c21c..3366184 100644
--- a/third_party/WebKit/Source/modules/payments/PaymentDetailsModifier.idl
+++ b/third_party/WebKit/Source/modules/payments/PaymentDetailsModifier.idl
@@ -5,7 +5,13 @@
 // https://w3c.github.io/browser-payment-api/#idl-def-paymentdetailsmodifier
 
 dictionary PaymentDetailsModifier {
-    required sequence<DOMString> supportedMethods;
+    // The following member should be DOMString type[1][2] but we define it
+    // as union type of DOMString and sequence<DOMString> for backward
+    // compatibility.
+    //
+    // [1] https://github.com/w3c/browser-payment-api/pull/551
+    // [2] https://w3c.github.io/browser-payment-api/#paymentdetailsmodifier-dictionary
+    required (DOMString or sequence<DOMString>) supportedMethods;
     PaymentItem total;
     sequence<PaymentItem> additionalDisplayItems;
     [RuntimeEnabled=PaymentDetailsModifierData] object data;
diff --git a/third_party/WebKit/Source/modules/payments/PaymentEventDataConversion.cpp b/third_party/WebKit/Source/modules/payments/PaymentEventDataConversion.cpp
index 2d6d6ba..9f4e998 100644
--- a/third_party/WebKit/Source/modules/payments/PaymentEventDataConversion.cpp
+++ b/third_party/WebKit/Source/modules/payments/PaymentEventDataConversion.cpp
@@ -42,7 +42,8 @@ PaymentDetailsModifier ToPaymentDetailsModifier(
   for (const auto& web_method : web_modifier.supported_methods) {
     supported_methods.push_back(web_method);
   }
-  modifier.setSupportedMethods(supported_methods);
+  modifier.setSupportedMethods(
+      StringOrStringSequence::fromStringSequence(supported_methods));
   modifier.setTotal(ToPaymentItem(web_modifier.total));
   HeapVector<PaymentItem> additional_display_items;
   for (const auto& web_item : web_modifier.additional_display_items) {
@@ -75,7 +76,8 @@ PaymentMethodData ToPaymentMethodData(
   for (const auto& method : web_method_data.supported_methods) {
     supported_methods.push_back(method);
   }
-  method_data.setSupportedMethods(supported_methods);
+  method_data.setSupportedMethods(
+      StringOrStringSequence::fromStringSequence(supported_methods));
   method_data.setData(
       StringDataToScriptValue(script_state, web_method_data.stringified_data));
   return method_data;
diff --git a/third_party/WebKit/Source/modules/payments/PaymentEventDataConversionTest.cpp b/third_party/WebKit/Source/modules/payments/PaymentEventDataConversionTest.cpp
index 5924916..de404e5 100644
--- a/third_party/WebKit/Source/modules/payments/PaymentEventDataConversionTest.cpp
+++ b/third_party/WebKit/Source/modules/payments/PaymentEventDataConversionTest.cpp
@@ -70,8 +70,16 @@ TEST(PaymentEventDataConversionTest, ToCanMakePaymentEventData) {
   ASSERT_TRUE(data.hasMethodData());
   ASSERT_EQ(1UL, data.methodData().size());
   ASSERT_TRUE(data.methodData().front().hasSupportedMethods());
-  ASSERT_EQ(1UL, data.methodData().front().supportedMethods().size());
-  ASSERT_EQ("foo", data.methodData().front().supportedMethods().front());
+  ASSERT_EQ(1UL, data.methodData()
+                     .front()
+                     .supportedMethods()
+                     .getAsStringSequence()
+                     .size());
+  ASSERT_EQ("foo", data.methodData()
+                       .front()
+                       .supportedMethods()
+                       .getAsStringSequence()
+                       .front());
   ASSERT_TRUE(data.methodData().front().hasData());
   ASSERT_TRUE(data.methodData().front().data().IsObject());
   String stringified_data = V8StringToWebCoreString<String>(
@@ -103,8 +111,16 @@ TEST(PaymentEventDataConversionTest, ToPaymentRequestEventData) {
   ASSERT_TRUE(data.hasMethodData());
   ASSERT_EQ(1UL, data.methodData().size());
   ASSERT_TRUE(data.methodData().front().hasSupportedMethods());
-  ASSERT_EQ(1UL, data.methodData().front().supportedMethods().size());
-  ASSERT_EQ("foo", data.methodData().front().supportedMethods().front());
+  ASSERT_EQ(1UL, data.methodData()
+                     .front()
+                     .supportedMethods()
+                     .getAsStringSequence()
+                     .size());
+  ASSERT_EQ("foo", data.methodData()
+                       .front()
+                       .supportedMethods()
+                       .getAsStringSequence()
+                       .front());
   ASSERT_TRUE(data.methodData().front().hasData());
   ASSERT_TRUE(data.methodData().front().data().IsObject());
   String stringified_data = V8StringToWebCoreString<String>(
diff --git a/third_party/WebKit/Source/modules/payments/PaymentMethodData.idl b/third_party/WebKit/Source/modules/payments/PaymentMethodData.idl
index a9c9237..b2c20e2 100644
--- a/third_party/WebKit/Source/modules/payments/PaymentMethodData.idl
+++ b/third_party/WebKit/Source/modules/payments/PaymentMethodData.idl
@@ -5,6 +5,12 @@
 // https://w3c.github.io/browser-payment-api/#idl-def-paymentmethoddata
 
 dictionary PaymentMethodData {
-    required sequence<DOMString> supportedMethods;
+    // The following member should be DOMString type[1][2] but we define it
+    // as union type of DOMString and sequence<DOMString> for backward
+    // compatibility.
+    //
+    // [1] https://github.com/w3c/browser-payment-api/pull/551
+    // [2] https://w3c.github.io/browser-payment-api/#paymentmethoddata-dictionary
+    required (DOMString or sequence<DOMString>) supportedMethods;
     object data;
 };
diff --git a/third_party/WebKit/Source/modules/payments/PaymentRequest.cpp b/third_party/WebKit/Source/modules/payments/PaymentRequest.cpp
index 7a5e29fa..a12b35c 100644
--- a/third_party/WebKit/Source/modules/payments/PaymentRequest.cpp
+++ b/third_party/WebKit/Source/modules/payments/PaymentRequest.cpp
@@ -571,19 +571,21 @@ void ValidateAndConvertPaymentDetailsModifiers(
         return;
     }
 
-    if (modifier.supportedMethods().IsEmpty()) {
+    if (modifier.supportedMethods().getAsStringSequence().IsEmpty()) {
       exception_state.ThrowTypeError(
           "Must specify at least one payment method identifier");
       return;
     }
 
-    if (modifier.supportedMethods().size() > kMaxListSize) {
+    if (modifier.supportedMethods().getAsStringSequence().size() >
+        kMaxListSize) {
       exception_state.ThrowTypeError(
           "At most 1024 supportedMethods allowed for modifier");
       return;
     }
 
-    for (const String& method : modifier.supportedMethods()) {
+    for (const String& method :
+         modifier.supportedMethods().getAsStringSequence()) {
       if (method.length() > kMaxStringLength) {
         exception_state.ThrowTypeError(
             "Supported method name for identifier cannot be longer than 1024 "
@@ -592,15 +594,16 @@ void ValidateAndConvertPaymentDetailsModifiers(
       }
     }
     CountPaymentRequestNetworkNameInSupportedMethods(
-        modifier.supportedMethods(), execution_context);
+        modifier.supportedMethods().getAsStringSequence(), execution_context);
 
     output.back()->method_data =
         payments::mojom::blink::PaymentMethodData::New();
-    output.back()->method_data->supported_methods = modifier.supportedMethods();
+    output.back()->method_data->supported_methods =
+        modifier.supportedMethods().getAsStringSequence();
 
     if (modifier.hasData() && !modifier.data().IsEmpty()) {
       StringifyAndParseMethodSpecificData(
-          modifier.supportedMethods(), modifier.data(),
+          modifier.supportedMethods().getAsStringSequence(), modifier.data(),
           output.back()->method_data, exception_state);
     } else {
       output.back()->method_data->stringified_data = "";
@@ -700,20 +703,24 @@ void ValidateAndConvertPaymentMethodData(
   }
 
   for (const PaymentMethodData payment_method_data : input) {
-    if (payment_method_data.supportedMethods().IsEmpty()) {
+    if (payment_method_data.supportedMethods()
+            .getAsStringSequence()
+            .IsEmpty()) {
       exception_state.ThrowTypeError(
           "Each payment method needs to include at least one payment method "
           "identifier");
       return;
     }
 
-    if (payment_method_data.supportedMethods().size() > kMaxListSize) {
+    if (payment_method_data.supportedMethods().getAsStringSequence().size() >
+        kMaxListSize) {
       exception_state.ThrowTypeError(
           "At most 1024 payment method identifiers are supported");
       return;
     }
 
-    for (const String identifier : payment_method_data.supportedMethods()) {
+    for (const String identifier :
+         payment_method_data.supportedMethods().getAsStringSequence()) {
       if (identifier.length() > kMaxStringLength) {
         exception_state.ThrowTypeError(
             "A payment method identifier cannot be longer than 1024 "
@@ -723,16 +730,18 @@ void ValidateAndConvertPaymentMethodData(
     }
 
     CountPaymentRequestNetworkNameInSupportedMethods(
-        payment_method_data.supportedMethods(), execution_context);
+        payment_method_data.supportedMethods().getAsStringSequence(),
+        execution_context);
 
     output.push_back(payments::mojom::blink::PaymentMethodData::New());
-    output.back()->supported_methods = payment_method_data.supportedMethods();
+    output.back()->supported_methods =
+        payment_method_data.supportedMethods().getAsStringSequence();
 
     if (payment_method_data.hasData() &&
         !payment_method_data.data().IsEmpty()) {
       StringifyAndParseMethodSpecificData(
-          payment_method_data.supportedMethods(), payment_method_data.data(),
-          output.back(), exception_state);
+          payment_method_data.supportedMethods().getAsStringSequence(),
+          payment_method_data.data(), output.back(), exception_state);
     } else {
       output.back()->stringified_data = "";
     }
diff --git a/third_party/WebKit/Source/modules/payments/PaymentTestHelper.cpp b/third_party/WebKit/Source/modules/payments/PaymentTestHelper.cpp
index f8a788a..5fa462d 100644
--- a/third_party/WebKit/Source/modules/payments/PaymentTestHelper.cpp
+++ b/third_party/WebKit/Source/modules/payments/PaymentTestHelper.cpp
@@ -135,7 +135,9 @@ PaymentDetailsModifier BuildPaymentDetailsModifierForTest(
     item = BuildPaymentItemForTest();
 
   PaymentDetailsModifier modifier;
-  modifier.setSupportedMethods(Vector<String>(1, "foo"));
+  StringOrStringSequence supportedMethods;
+  supportedMethods.setStringSequence(Vector<String>(1, "foo"));
+  modifier.setSupportedMethods(supportedMethods);
   modifier.setTotal(total);
   modifier.setAdditionalDisplayItems(HeapVector<PaymentItem>(1, item));
   return modifier;
@@ -191,7 +193,9 @@ PaymentDetailsUpdate BuildPaymentDetailsErrorMsgForTest(
 
 HeapVector<PaymentMethodData> BuildPaymentMethodDataForTest() {
   HeapVector<PaymentMethodData> method_data(1, PaymentMethodData());
-  method_data[0].setSupportedMethods(Vector<String>(1, "foo"));
+  StringOrStringSequence supportedMethods;
+  supportedMethods.setStringSequence(Vector<String>(1, "foo"));
+  method_data[0].setSupportedMethods(supportedMethods);
   return method_data;
 }
 
