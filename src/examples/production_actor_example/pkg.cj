/*
 * CActor 生产级Actor例子包配置
 */

package cactor.examples.production_actor_example

import cactor.core.config.*
import cactor.core.message.Message
import cactor.core.actor.{Actor, ActorRef, ActorPath}
import cactor.core.context.ActorContext
import cactor.core.message.MessageResult
import cactor.runtime.mailbox.factory.AdvancedMailboxFactory
import cactor.runtime.dispatcher.factory.AdvancedDispatcherFactory
