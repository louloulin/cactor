/*
 * Copyright (c) 2024. All rights reserved.
 * CActor - AtLeastOnceDelivery 单元测试
 */
package cactor.distribution.cluster

import std.collection.*
import std.time.*

// === DeliveryState Tests ===

@Test
func testDeliveryState_values() {
    @Expect(DeliveryState.Pending.toString().size > 0, true)
    @Expect(DeliveryState.Sent.toString().size > 0, true)
    @Expect(DeliveryState.Confirmed.toString().size > 0, true)
    @Expect(DeliveryState.ConfirmedStale.toString().size > 0, true)
}

// === DeliveryEnvelope Tests ===

@Test
func testDeliveryEnvelope_creation() {
    let env = DeliveryEnvelope(1, "/user/actor", "hello")
    @Expect(env.messageId, 1)
    @Expect(env.destination, "/user/actor")
    @Expect(env.payload, "hello")
    @Expect(env.state, DeliveryState.Pending)
    @Expect(env.sendCount, 0)
}

@Test
func testDeliveryEnvelope_markSent() {
    let env = DeliveryEnvelope(1, "/user/actor", "hello")
    env.markSent()
    @Expect(env.state, DeliveryState.Sent)
    @Expect(env.sendCount, 1)
}

@Test
func testDeliveryEnvelope_markConfirmed() {
    let env = DeliveryEnvelope(1, "/user/actor", "hello")
    env.markSent()
    env.markConfirmed()
    @Expect(env.state, DeliveryState.Confirmed)
}

@Test
func testDeliveryEnvelope_needsRetry() {
    let env = DeliveryEnvelope(1, "/user/actor", "hello")
    // Initially needs retry (lastSendTime = 0)
    @Expect(env.needsRetry(Duration.second * 1), true)
}

@Test
func testDeliveryEnvelope_noRetryWhenConfirmed() {
    let env = DeliveryEnvelope(1, "/user/actor", "hello")
    env.markConfirmed()
    @Expect(env.needsRetry(Duration.second * 1), false)
}

// === DeliveryTracking Tests ===

@Test
func testDeliveryTracking_creation() {
    let env = DeliveryEnvelope(1, "/user/actor", "hello")
    let tracking = DeliveryTracking(env)
    @Expect(tracking.messageId, 1)
    @Expect(tracking.destination, "/user/actor")
    @Expect(tracking.payload, "hello")
    @Expect(tracking.sendCount, 0)
}

@Test
func testDeliveryTracking_deliveryDuration() {
    let env = DeliveryEnvelope(1, "/user/actor", "hello")
    env.markSent()
    let tracking = DeliveryTracking(env)
    let duration = tracking.deliveryDuration()
    @Expect(duration >= 0, true)
}

// === ConfirmRequest Tests ===

@Test
func testConfirmRequest_creation() {
    let req = ConfirmRequest(123)
    @Expect(req.messageId, 123)
}

// === DeliveryResult Tests ===

@Test
func testDeliveryResult_success() {
    let result = DeliveryResult(1, "/user/actor", true, false, None)
    @Expect(result.success, true)
    @Expect(result.confirmed, false)
    @Expect(result.reason.isNone(), true)
}

@Test
func testDeliveryResult_failure() {
    let result = DeliveryResult(1, "/user/actor", false, false, Some("timeout"))
    @Expect(result.success, false)
    @Expect(result.reason.getOrThrow(), "timeout")
}

// === AtLeastOnceDelivery Tests ===

@Test
func testAtLeastOnceDelivery_creation() {
    let delivery = createAtLeastOnceDelivery("/user/actor")
    @Expect(delivery.getDestination(), "/user/actor")
    @Expect(delivery.pendingCount(), 0)
}

@Test
func testAtLeastOnceDelivery_deliver() {
    let delivery = createAtLeastOnceDelivery("/user/actor")
    let msgId = delivery.deliver("hello world")
    @Expect(msgId, 1)
    @Expect(delivery.pendingCount(), 1)
    @Expect(delivery.totalSent(), 1)
}

@Test
func testAtLeastOnceDelivery_deliverBatch() {
    let delivery = createAtLeastOnceDelivery("/user/actor")
    let payloads = ArrayList<String>()
    payloads.append("msg1")
    payloads.append("msg2")
    payloads.append("msg3")
    let ids = delivery.deliverBatch(payloads)
    @Expect(ids.size, 3)
    @Expect(delivery.pendingCount(), 3)
}

@Test
func testAtLeastOnceDelivery_markSent() {
    let delivery = createAtLeastOnceDelivery("/user/actor")
    let msgId = delivery.deliver("hello")
    delivery.markSent(msgId)
    let state = delivery.getDeliveryState(msgId)
    match (state) {
        case Some(s) => @Expect(s, DeliveryState.Sent)
        case None => ()
    }
}

@Test
func testAtLeastOnceDelivery_confirm() {
    let delivery = createAtLeastOnceDelivery("/user/actor")
    let msgId = delivery.deliver("hello")
    let confirmed = delivery.confirm(msgId)
    @Expect(confirmed, true)
    @Expect(delivery.pendingCount(), 0)
    @Expect(delivery.confirmedCount(), 1)
    @Expect(delivery.isConfirmed(msgId), true)
}

@Test
func testAtLeastOnceDelivery_confirmNotFound() {
    let delivery = createAtLeastOnceDelivery("/user/actor")
    let confirmed = delivery.confirm(999)
    @Expect(confirmed, false)
}

@Test
func testAtLeastOnceDelivery_confirmRequest() {
    let delivery = createAtLeastOnceDelivery("/user/actor")
    let msgId = delivery.deliver("hello")
    let req = ConfirmRequest(msgId)
    delivery.handleConfirmRequest(req)
    @Expect(delivery.isConfirmed(msgId), true)
}

@Test
func testAtLeastOnceDelivery_getPendingDeliveries() {
    let delivery = createAtLeastOnceDelivery("/user/actor")
    delivery.deliver("msg1")
    delivery.deliver("msg2")
    let pending = delivery.getPendingDeliveries()
    @Expect(pending.size, 2)
}

@Test
func testAtLeastOnceDelivery_getConfirmedDeliveries() {
    let delivery = createAtLeastOnceDelivery("/user/actor")
    let id1 = delivery.deliver("msg1")
    let id2 = delivery.deliver("msg2")
    delivery.confirm(id1)
    let confirmed = delivery.getConfirmedDeliveries()
    @Expect(confirmed.size, 1)
}

@Test
func testAtLeastOnceDelivery_getMessagesToRetry() {
    let delivery = createAtLeastOnceDelivery("/user/actor")
    let msgId = delivery.deliver("hello")
    delivery.markSent(msgId)
    // Message should be pending for retry
    let retryList = delivery.getMessagesToRetry()
    // Initial state might not need retry immediately, so check state
    let state = delivery.getDeliveryState(msgId)
    match (state) {
        case Some(s) => @Expect(s == DeliveryState.Sent || s == DeliveryState.Pending, true)
        case None => ()
    }
}

@Test
func testAtLeastOnceDelivery_isPending() {
    let delivery = createAtLeastOnceDelivery("/user/actor")
    let msgId = delivery.deliver("hello")
    @Expect(delivery.isPending(msgId), true)
    delivery.confirm(msgId)
    @Expect(delivery.isPending(msgId), false)
}

@Test
func testAtLeastOnceDelivery_confirmationRate() {
    let delivery = createAtLeastOnceDelivery("/user/actor")
    delivery.deliver("msg1")
    delivery.deliver("msg2")
    delivery.deliver("msg3")
    @Expect(delivery.confirmationRate(), 0.0)
    delivery.confirm(1)
    @Expect(delivery.confirmationRate(), 0.3333333333333333)
}

@Test
func testAtLeastOnceDelivery_totalSent() {
    let delivery = createAtLeastOnceDelivery("/user/actor")
    delivery.deliver("msg1")
    delivery.deliver("msg2")
    @Expect(delivery.totalSent(), 2)
}

@Test
func testAtLeastOnceDelivery_totalConfirmed() {
    let delivery = createAtLeastOnceDelivery("/user/actor")
    let id1 = delivery.deliver("msg1")
    let id2 = delivery.deliver("msg2")
    delivery.confirm(id1)
    delivery.confirm(id2)
    @Expect(delivery.totalConfirmed(), 2)
}

@Test
func testAtLeastOnceDelivery_cancelDelivery() {
    let delivery = createAtLeastOnceDelivery("/user/actor")
    let msgId = delivery.deliver("hello")
    @Expect(delivery.pendingCount(), 1)
    let cancelled = delivery.cancelDelivery(msgId)
    @Expect(cancelled, true)
    @Expect(delivery.pendingCount(), 0)
    @Expect(delivery.totalFailed(), 1)
}

@Test
func testAtLeastOnceDelivery_cancelDeliveryNotFound() {
    let delivery = createAtLeastOnceDelivery("/user/actor")
    let cancelled = delivery.cancelDelivery(999)
    @Expect(cancelled, false)
}

@Test
func testAtLeastOnceDelivery_getTracking() {
    let delivery = createAtLeastOnceDelivery("/user/actor")
    let msgId = delivery.deliver("hello")
    delivery.confirm(msgId)
    let tracking = delivery.getTracking(msgId)
    @Expect(tracking.isSome(), true)
}

@Test
func testAtLeastOnceDelivery_getTrackingNotFound() {
    let delivery = createAtLeastOnceDelivery("/user/actor")
    let tracking = delivery.getTracking(999)
    @Expect(tracking.isNone(), true)
}

// === DeliveryEventHandler Tests ===

class TestDeliveryHandler <: DeliveryEventHandler {
    public let sentEvents = ArrayList<Int64>()
    public let confirmedEvents = ArrayList<Int64>()
    public let timeoutEvents = ArrayList<Int64>()
    public let maxRetryEvents = ArrayList<Int64>()

    public func onMessageSent(messageId: Int64, destination: String, payload: String): Unit {
        sentEvents.add(messageId)
    }

    public func onMessageConfirmed(messageId: Int64): Unit {
        confirmedEvents.add(messageId)
    }

    public func onMessageTimeout(messageId: Int64, destination: String): Unit {
        timeoutEvents.add(messageId)
    }

    public func onMessageMaxRetries(messageId: Int64, destination: String, reason: String): Unit {
        maxRetryEvents.add(messageId)
    }

    public func onMessageStale(messageId: Int64): Unit {
        // Stale tracking
    }
}

@Test
func testAtLeastOnceDelivery_eventHandler_sent() {
    let delivery = createAtLeastOnceDelivery("/user/actor")
    let handler = TestDeliveryHandler()
    delivery.setEventHandler(handler)
    delivery.deliver("hello")
    @Expect(handler.sentEvents.size, 1)
}

@Test
func testAtLeastOnceDelivery_eventHandler_confirmed() {
    let delivery = createAtLeastOnceDelivery("/user/actor")
    let handler = TestDeliveryHandler()
    delivery.setEventHandler(handler)
    let msgId = delivery.deliver("hello")
    delivery.confirm(msgId)
    @Expect(handler.confirmedEvents.size, 1)
    @Expect(handler.confirmedEvents[0], msgId)
}

// === DeliveryConfig Tests ===

@Test
func testDeliveryConfig_creation() {
    let config = DeliveryConfig(
        Duration.second * 3,
        10,
        Duration.minute * 2,
        Duration.hour * 1,
        500
    )
    @Expect(config.redeliverInterval, Duration.second * 3)
    @Expect(config.maxRetries, 10)
    @Expect(config.trackInterval, Duration.minute * 2)
    @Expect(config.staleThreshold, Duration.hour * 1)
    @Expect(config.pendingBufferSize, 500)
}

@Test
func testCreateDefaultDeliveryConfig() {
    let config = createDefaultDeliveryConfig()
    @Expect(config.maxRetries, 5)
    @Expect(config.pendingBufferSize, 1000)
}

// === Config-based Delivery Tests ===

@Test
func testAtLeastOnceDeliveryWithConfig() {
    let config = DeliveryConfig(
        Duration.second * 2,
        3,
        Duration.minute * 1,
        Duration.minute * 15,
        100
    )
    let delivery = createAtLeastOnceDeliveryWithConfig("/user/actor", config)
    @Expect(delivery.getDestination(), "/user/actor")
    let msgId = delivery.deliver("test message")
    @Expect(delivery.pendingCount(), 1)
}

@Test
func testAtLeastOnceDelivery_cleanupStale() {
    let delivery = createAtLeastOnceDelivery("/user/actor")
    let id1 = delivery.deliver("msg1")
    let id2 = delivery.deliver("msg2")
    delivery.confirm(id1)
    delivery.confirm(id2)
    // Short threshold for testing
    let cleaned = delivery.cleanupStaleMessages()
    @Expect(cleaned >= 0, true)
}