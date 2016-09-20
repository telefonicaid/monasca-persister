/*
 * Copyright (c) 2016 Telefónica I+D
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
 * implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package monasca.persister.consumer;

import com.google.inject.Inject;
import com.google.inject.assistedinject.Assisted;
import monasca.persister.pipeline.ManagedPipeline;
import monasca.persister.repository.RepoException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.slf4j.MDC;

import java.net.DatagramPacket;
import java.net.DatagramSocket;
import java.net.InetSocketAddress;
import java.util.UUID;

public class KafkaConsumerRunnableExtended<T> extends KafkaConsumerRunnableBasic<T> {

  private static final Logger logger = LoggerFactory.getLogger(KafkaConsumerRunnableExtended.class);
  private static final String MSG_ID = "msgId";

  private InetSocketAddress remoteEndpoint;
  private DatagramSocket udpSocket;

  @Inject
  public KafkaConsumerRunnableExtended(
      @Assisted KafkaChannel kafkaChannel,
      @Assisted ManagedPipeline<T> pipeline,
      @Assisted("threadId") String threadId,
      @Assisted("remoteEndpoint") String remoteEndpoint) {

    super(kafkaChannel, pipeline, threadId);
    this.remoteEndpoint = null;
    this.udpSocket = null;

    if (remoteEndpoint != null) {
      try {
        String[] items = remoteEndpoint.split(":");
        this.remoteEndpoint = new InetSocketAddress(items[0], Integer.parseInt(items[1]));
        this.udpSocket = new DatagramSocket(null);
      } catch (Exception e) {
        logger.error("Could not create UDP socket to send metrics to " + remoteEndpoint, e);
        this.remoteEndpoint = null;
        this.udpSocket = null;
      }
    }
  }

  protected void publishEvent(final String msg) throws RepoException {

    if (msg == null) {
      logger.debug("Ignoring null metric");
    } else {
      super.publishEvent(msg);
      if (remoteEndpoint != null) {
        String uuid = UUID.randomUUID().toString();
        String data = msg.replace("\"meta\":{", "\"meta\":{" + "\"" + MSG_ID + "\":\"" + uuid + "\",");
        MDC.put(MSG_ID, uuid);
        try {
          DatagramPacket packet = new DatagramPacket(data.getBytes(), data.length(), remoteEndpoint);
          udpSocket.send(packet);
          logger.debug("Metric sent to {}", remoteEndpoint.toString());
        } catch (Exception e) {
          logger.error("Could not send metric to {}", remoteEndpoint.toString());
        } finally {
          MDC.remove(MSG_ID);
        }
      }
    }
  }
}
