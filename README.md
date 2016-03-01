JVM GC Log redirection to the Java logging framework
====================================================

The sample Windows Powershell script [GCLogPipeServer.ps1](GCLogPipeServer.ps1) can be used
to redirect JVM GC log output to the application running within the JVM itself in order to 
gather application logs and JVM GC logs in a consistent manner, e.g. using Logback logging 
framework on a Windows machine.

Building the demo Java application
----------------------------------
````
mvn package
````

Example usage
-------------
1. Run this script without any parameters first

	````
		.\GCLogPipeServer.ps1
	````
	
2. Run the JVM application with GC log redirected to the inbound named pipe created by this script, e.g.

	````
			java -Xloggc:\\.\pipe\GCLogNamedPipeInbound -XX:+PrintGC -XX:+PrintGCDetails -XX:+PrintGCTimeStamps \
				-XX:+PrintGCDateStamps -Xms32M -Xmx32M -jar target\gc-logger-0.0.1-SNAPSHOT.jar
	````
	
3. Read from the `\\.\pipe\GCLogNamedPipeOutbound` named pipe in a special thread in the Java application
	and redirect the received GC logs to any desired logging framework, e.g. Logback via SLF4J: [GcLogger.java](src/main/java/test/gc/GcLogger.java)

4. Notice the JVM GC Log output landing in the regular application console logs in Logback format

_Please note, asynchronous appender is strongly recommended here to avoid losing GC output and potential deadlocks!_

