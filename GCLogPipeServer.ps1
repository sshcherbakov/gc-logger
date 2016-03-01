# This is a sample script for redirecting JVM GC log output to the application running within
# the JVM itself in order to gather application logs and JVM GC logs in consistent manner, e.g.
# using Logback logging framework
#
# Example usage:
# 1) Run this script without any parameters first
#		.\GCLogPipeServer.ps1
# 2) Run the JVM application with GC log redirected to the inbound named pipe created by this script, e.g.
# 		java -Xloggc:\\.\pipe\GCLogNamedPipeInbound -XX:+PrintGC -XX:+PrintGCDetails -XX:+PrintGCTimeStamps \
# 			-XX:+PrintGCDateStamps -Xms32M -Xmx32M -jar target\gc-logger-0.0.1-SNAPSHOT.jar
# 3) Read from the \\.\pipe\GCLogNamedPipeOutbound named pipe in a special thread in the Java application
# 	and redirect the received GC logs to any desired logging framework, e.g. Logback via SLF4J.
#	Please note, asynchronous appender is strongly recommended here to avoid potential deadlocks!
#
try {
	'Waiting for Inbound connection'
	$npipeInboundServer = new-object System.IO.Pipes.NamedPipeServerStream('GCLogNamedPipeInbound', [System.IO.Pipes.PipeDirection]::InOut)
	$pipeInboundReader = new-object System.IO.StreamReader($npipeInboundServer)

	$npipeOutboundServer = new-object System.IO.Pipes.NamedPipeServerStream('GCLogNamedPipeOutbound', [System.IO.Pipes.PipeDirection]::InOut)
	$pipeOutboundWriter = new-object System.IO.StreamWriter($npipeOutboundServer)
	
	$npipeInboundServer.WaitForConnection()
	'Inbound connection established'	
	
	# We need to wait for connection asynchronously here because
	# we would block this script for reading JVM GC log output.
	# When JVM cannot write the GC log the entire JVM including
	# custom logging freezes. So we need to proceed to draining
	# the JVM GC logs ASAP.
	'Waiting for outbound connection'		
	$asyncConnHandle = $npipeOutboundServer.WaitForConnectionAsync()
	
	$asyncHandle = $null
	while (1)
	{
		$msg = $pipeInboundReader.ReadLine()
		if( $msg -eq $null ) 
		{
			'Client disconnects'
			break 
		}
		
		# This is a check to allow reading of JVM GC logs even before the 
		# custom logging code in the JVM is initialized and started.
		# When JVM cannot write the GC log is freezes entire process and
		# doesn't give a chance for the application code to initialize logging
		# and connect to the outbound pipe effectively resulting in a deadlock.
		# Therefore using this check we may skip several GC log outputs at the
		# application start-up in favour of avoiding deadlocks and keeping this 
		# script mainly single threaded
		if( $npipeOutboundServer.IsConnected )
		{ 
			if( $asyncHandle -eq $null -or $asyncHandle.IsCompleted) 
			{
				# Asynchronous writing is needed here to free the main thread for reading
				# ASAP. Otherwise the JVM GC log write will block on write and freeze  
				# entire JVM including custom logging, which means a deadlock
				$asyncHandle = $pipeOutboundWriter.WriteLineAsync( $msg )
			}
			else 
			{
				# We should never land here, since it means we are dropping inbound messages
				# We may land here in case when the downstream endpoint processes our writes
				# slower than our upstream produces them
				# In case of JVM GC logging that would mean JVM blocking on GC log write
				# Use Logback AsyncAppender in order to speedup logging on the downstream side
				# and avoid losing log messages here
				$msg
			}
		}
	}
}
finally 
{
	if($npipeOutboundServer -ne $null) { $npipeOutboundServer.Dispose() }
	if($npipeInboundServer -ne $null) { $npipeInboundServer.Dispose() }
}