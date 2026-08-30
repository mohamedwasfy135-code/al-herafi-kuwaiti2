import 'package:flutter/material.dart';
import '../../../core/services/call_service.dart';

class CallPage extends StatefulWidget {
  final String callId;
  final String userId;
  final String userName;
  final String otherUserId;
  final Map<String, dynamic>? offer;
  final bool isCaller;

  const CallPage({
    super.key,
    required this.callId,
    required this.userId,
    required this.userName,
    required this.otherUserId,
    this.offer,
    required this.isCaller,
  });

  @override
  State<CallPage> createState() => _CallPageState();
}

class _CallPageState extends State<CallPage> {
  bool _muted = false;
  bool _speakerOn = true;
  bool _connecting = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initCall();
  }

  Future<void> _initCall() async {
    try {
      if (widget.isCaller) {
        // المتصل: إنشاء المكالمة
        await CallService.createCall(
          callerId: widget.userId,
          callerName: widget.userName,
          receiverId: widget.otherUserId,
          offer: widget.offer ?? {},
        );
      } else if (widget.offer != null) {
        // المستقبل: قبول المكالمة
        await CallService.updateAnswer(
          callId: widget.callId,
          answer: widget.offer!,
        );
      }

      if (mounted) {
        setState(() => _connecting = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _connecting = false;
        });
      }
    }
  }

  void _toggleMute() => setState(() => _muted = !_muted);
  void _toggleSpeaker() => setState(() => _speakerOn = !_speakerOn);

  void _hangUp() {
    CallService.endCall(widget.callId);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      appBar: AppBar(
        title: Text(widget.userName),
        backgroundColor: Colors.black,
        automaticallyImplyLeading: false,
      ),
      body: _connecting
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, size: 60, color: Colors.red),
                        const SizedBox(height: 20),
                        const Text('فشلت المكالمة', style: TextStyle(color: Colors.white, fontSize: 18)),
                        const SizedBox(height: 10),
                        Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                        const SizedBox(height: 30),
                        ElevatedButton(onPressed: _hangUp, child: const Text('خروج')),
                      ],
                    ),
                  ),
                )
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.phone_in_talk, size: 80, color: Colors.green),
                      const SizedBox(height: 20),
                      const Text('مكالمة جارية', style: TextStyle(color: Colors.white, fontSize: 18)),
                      const SizedBox(height: 40),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          IconButton(
                            icon: Icon(_muted ? Icons.mic_off : Icons.mic, color: Colors.white, size: 40),
                            onPressed: _toggleMute,
                          ),
                          IconButton(
                            icon: Icon(_speakerOn ? Icons.volume_up : Icons.volume_mute, color: Colors.white, size: 40),
                            onPressed: _toggleSpeaker,
                          ),
                        ],
                      ),
                      const SizedBox(height: 60),
                      IconButton(
                        icon: const Icon(Icons.call_end, color: Colors.red, size: 60),
                        onPressed: _hangUp,
                      ),
                    ],
                  ),
                ),
    );
  }
}
