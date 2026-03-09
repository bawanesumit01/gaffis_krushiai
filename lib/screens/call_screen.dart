import 'package:flutter/material.dart';
import 'package:vapi/vapi.dart';

class CallScreen extends StatefulWidget {
  final bool isVideo;
  final String languageCode;
  final String ttsCode;
  final String languageName;

  const CallScreen({
    super.key,
    required this.isVideo,
    required this.languageCode,
    required this.ttsCode,
    required this.languageName,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen>
    with SingleTickerProviderStateMixin {

  static const _vapiKey     = '2fddc4fe-c494-46b8-af1a-21ffc18c191a';
  static const _assistantId = 'bdaef2c6-7435-49bd-95ed-4763225ce04b';

  VapiClient? _client;
  VapiCall?   _call;

  bool _callActive = false;
  bool _isSpeaking = false;
  bool _isStarting = true;
  String _statusText = 'Connecting...';

  late AnimationController _pulseCtrl;
  late Animation<double>   _pulse;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _startCall();
  }

  Future<void> _startCall() async {
    _client = VapiClient(_vapiKey);

    try {
      _call = await _client!.start(
        assistantId: _assistantId,
        assistantOverrides: {
          'firstMessage': _greeting(),
          // ✅ Only override firstMessage and system prompt
          // Do NOT override model — use whatever model you set in Vapi dashboard
          'model': {
            'provider': 'google',   // ✅ required field
            'model': 'gemini-2.0-flash',
            'messages': [
              {'role': 'system', 'content': _systemPrompt()},
            ],
          },
        },
      );

      _call!.onEvent.listen((event) {
        if (!mounted) return;
        switch (event.label) {
          case 'call-start':
            setState(() {
              _callActive = true;
              _isStarting = false;
              _isSpeaking = false;
              _statusText = 'Listening...';
            });
            break;
          case 'call-end':
            setState(() {
              _callActive = false;
              _statusText = 'Call ended';
            });
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) Navigator.pop(context);
            });
            break;
          case 'speech-start':
            setState(() {
              _isSpeaking = true;
              _statusText = 'AI Speaking...';
            });
            break;
          case 'speech-end':
            setState(() {
              _isSpeaking = false;
              _statusText = 'Listening...';
            });
            break;
          case 'error':
            setState(() {
              _isStarting = false;
              _statusText = 'Error. Tap end & retry.';
            });
            break;
        }
      });

    } catch (e) {
      if (mounted) {
        setState(() {
          _isStarting = false;
          _statusText = 'Failed: $e';
        });
      }
    }
  }

  String _greeting() {
    if (widget.languageCode == 'hi') {
      return 'नमस्ते! मैं गाफिस कृषि AI हूं। अपनी फसल के बारे में पूछें।';
    }
    if (widget.languageCode == 'mr') {
      return 'नमस्कार! मी गाफिस कृषी AI आहे. पिकाबद्दल विचारा.';
    }
    return 'Hello! I am Gaffis Krushi AI. Ask me about your crops.';
  }

  String _systemPrompt() {
    if (widget.languageCode == 'hi') {
      return 'आप गाफिस कृषि AI हैं। किसानों को सरल हिन्दी में '
          'छोटे वाक्यों में जवाब दें। केवल खेती, फसल, मिट्टी, '
          'कीट और मौसम से संबंधित प्रश्नों का उत्तर दें।';
    }
    if (widget.languageCode == 'mr') {
      return 'आपण गाफिस कृषी AI आहात. शेतकऱ्यांना सोप्या मराठीत '
          'छोट्या वाक्यांत उत्तर द्या. फक्त शेती, पिके, माती, '
          'कीड आणि हवामानाशी संबंधित प्रश्नांची उत्तरे द्या.';
    }
    return 'You are Gaffis Krushi AI. Reply to farmers in simple '
        'short English sentences. Only answer questions about '
        'farming, crops, soil, pests and weather.';
  }

  void _endCall() async {
    await _call?.stop();
    _client?.dispose();
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _call?.stop();
    _client?.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF071A0F),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.2),
            radius: 1.4,
            colors: [Color(0xFF0F3D22), Color(0xFF071A0F)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _Pill(isStarting: _isStarting, isSpeaking: _isSpeaking, callActive: _callActive),
                    Text(widget.languageName,
                        style: TextStyle(color: Colors.green.shade400, fontSize: 13)),
                  ],
                ),
              ),
              const Spacer(),
              AnimatedBuilder(
                animation: _pulse,
                builder: (_, child) => Transform.scale(
                  scale: _callActive ? _pulse.value : 1.0,
                  child: child,
                ),
                child: _Avatar(isSpeaking: _isSpeaking, callActive: _callActive),
              ),
              const SizedBox(height: 26),
              const Text('Gaffis Krushi AI',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 18),
              SizedBox(
                height: 44,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _isStarting
                      ? const _Dots(key: ValueKey('s'))
                      : _isSpeaking
                          ? _Wave(key: const ValueKey('spk'), color: const Color(0xFF4ADE80))
                          : _callActive
                              ? _Wave(key: const ValueKey('mic'), color: Colors.red.shade400)
                              : const SizedBox(key: ValueKey('n')),
                ),
              ),
              const SizedBox(height: 14),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  _statusText,
                  key: ValueKey(_statusText),
                  style: TextStyle(
                    color: _isSpeaking ? const Color(0xFF4ADE80) : Colors.white38,
                    fontSize: 14,
                  ),
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 52),
                child: Column(children: [
                  GestureDetector(
                    onTap: _endCall,
                    child: Container(
                      width: 70, height: 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.red.shade700,
                        boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.45), blurRadius: 24, spreadRadius: 4)],
                      ),
                      child: const Icon(Icons.call_end, color: Colors.white, size: 30),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('End Call', style: TextStyle(color: Colors.white38, fontSize: 12)),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final bool isStarting, isSpeaking, callActive;
  const _Pill({required this.isStarting, required this.isSpeaking, required this.callActive});
  @override
  Widget build(BuildContext context) {
    final color = isStarting ? Colors.orange : isSpeaking ? const Color(0xFF4ADE80) : callActive ? Colors.red : Colors.white38;
    final label = isStarting ? 'Connecting' : isSpeaking ? 'Speaking' : callActive ? 'Listening' : 'Ended';
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 7),
        Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

class _Avatar extends StatelessWidget {
  final bool isSpeaking, callActive;
  const _Avatar({required this.isSpeaking, required this.callActive});
  @override
  Widget build(BuildContext context) {
    final glow = isSpeaking ? const Color(0xFF4ADE80) : Colors.red;
    return Container(
      width: 144, height: 144,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: isSpeaking
            ? [const Color(0xFF1E6040), const Color(0xFF0D3020)]
            : [const Color(0xFF163D28), const Color(0xFF0A2518)]),
        boxShadow: [BoxShadow(color: glow.withOpacity(callActive ? 0.4 : 0.1), blurRadius: 44, spreadRadius: 10)],
        border: Border.all(
          color: isSpeaking ? const Color(0xFF4ADE80).withOpacity(0.5) : Colors.red.withOpacity(callActive ? 0.55 : 0.2),
          width: 2.5,
        ),
      ),
      child: Icon(Icons.agriculture, size: 70,
          color: isSpeaking ? const Color(0xFF4ADE80) : Colors.white.withOpacity(0.88)),
    );
  }
}

class _Wave extends StatefulWidget {
  final Color color;
  const _Wave({super.key, required this.color});
  @override State<_Wave> createState() => _WaveState();
}
class _WaveState extends State<_Wave> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override void initState() { super.initState(); _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..repeat(reverse: true); }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    const hs = [10.0, 20.0, 30.0, 38.0, 30.0, 20.0, 10.0];
    return AnimatedBuilder(animation: _c, builder: (_, __) => Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: List.generate(7, (i) {
        final v = ((_c.value + i * 0.13) % 1.0);
        final h = hs[i] * (0.3 + 0.7 * (v < 0.5 ? v * 2 : (1 - v) * 2));
        return Container(margin: const EdgeInsets.symmetric(horizontal: 3), width: 4.5, height: h,
            decoration: BoxDecoration(color: widget.color, borderRadius: BorderRadius.circular(3)));
      }),
    ));
  }
}

class _Dots extends StatefulWidget {
  const _Dots({super.key});
  @override State<_Dots> createState() => _DotsState();
}
class _DotsState extends State<_Dots> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override void initState() { super.initState(); _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(); }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(animation: _c, builder: (_, __) => Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final v = ((_c.value + i * 0.33) % 1.0);
        final s = v < 0.5 ? v * 2 : (1 - v) * 2;
        return Container(margin: const EdgeInsets.symmetric(horizontal: 5), width: 9, height: 9,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2 + 0.8 * s), shape: BoxShape.circle));
      }),
    ));
  }
}