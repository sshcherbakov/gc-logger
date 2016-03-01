package test.gc;

import java.io.RandomAccessFile;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class GcLogger {
	private static Logger log = LoggerFactory.getLogger(GcLogger.class);

	public static void main(final String[] args) throws Exception {

		log.info("**** TEST *****");

		new Thread(new Runnable() {

			@Override
			public void run() {
				log.info("**** DUMMY *****");
				while (true) {
					for (int i = 0; i < 1000; i++) {
						String h = new String("xxx");
						h += 1;
					}
				}
			}
		}).start();

		log.info("**** CONNECTING *****");

		try (RandomAccessFile pipe = new RandomAccessFile("\\\\.\\pipe\\GCLogNamedPipeOutbound", "rw")) {
			log.info("**** CONNECTED *****");
			String line = null;
			while ((line = pipe.readLine()) != null) {
				log.info("GC LOG OUTPUT >>>> {}", line);
			}

		} catch (Exception ex) {
			log.error("PANIC", ex);
		}

	}
}
