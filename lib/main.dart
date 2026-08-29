import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const SyncBeatApp());
}

class SyncBeatApp extends StatelessWidget {
  const SyncBeatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SyncBeat Online',
      theme: ThemeData.dark(useMaterial3: true),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _roomController = TextEditingController();

  String _generateRoomCode() {
    return (1000 + Random().nextInt(9000)).toString();
  }

  void _createRoom() {
    final roomCode = _generateRoomCode();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlayerRoomScreen(roomCode: roomCode, isHost: true),
      ),
    );
  }

  void _joinRoom() {
    final roomCode = _roomController.text.trim();
    if (roomCode.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PlayerRoomScreen(roomCode: roomCode, isHost: false),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SyncBeat - Online Music Sync')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: _createRoom,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Create New Sync Room (Host)'),
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            ),
            const SizedBox(height: 30),
            TextField(
              controller: _roomController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Enter 4-Digit Room Code',
                prefixIcon: Icon(Icons.meeting_room),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _joinRoom,
              icon: const Icon(Icons.group_add),
              label: const Text('Join Room (Listener)'),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            ),
          ],
        ),
      ),
    );
  }
}

class PlayerRoomScreen extends StatefulWidget {
  final String roomCode;
  final bool isHost;

  const PlayerRoomScreen({super.key, required this.roomCode, required this.isHost});

  @override
  State<PlayerRoomScreen> createState() => _PlayerRoomScreenState();
}

class _PlayerRoomScreenState extends State<PlayerRoomScreen> {
  late DatabaseReference _roomRef;
  late YoutubePlayerController _controller;
  final TextEditingController _urlController = TextEditingController();
  bool _isPlayerReady = false;
  String _currentVideoId = 'dQw4w9WgXcQ';

  @override
  void initState() {
    super.initState();
    _roomRef = FirebaseDatabase.instance.ref('rooms/${widget.roomCode}');

    _controller = YoutubePlayerController(
      initialVideoId: _currentVideoId,
      flags: const YoutubePlayerFlags(
        autoPlay: false,
        mute: false,
        enableCaption: false,
        isLive: false,
      ),
    )..addListener(_playerListener);

    if (widget.isHost) {
      _initHostState();
    } else {
      _listenToRoomUpdates();
    }
  }

  void _initHostState() {
    _roomRef.set({
      'videoId': _currentVideoId,
      'isPlaying': false,
      'positionMs': 0,
      'timestamp': ServerValue.timestamp,
    });
  }

  void _listenToRoomUpdates() {
    _roomRef.onValue.listen((event) {
      if (!event.snapshot.exists || !_isPlayerReady) return;

      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      final String videoId = data['videoId'] ?? _currentVideoId;
      final bool isPlaying = data['isPlaying'] ?? false;
      final int basePositionMs = data['positionMs'] ?? 0;
      final int serverTimestamp = data['timestamp'] ?? DateTime.now().millisecondsSinceEpoch;

      if (videoId != _currentVideoId) {
        setState(() => _currentVideoId = videoId);
        _controller.load(videoId);
      }

      final int now = DateTime.now().millisecondsSinceEpoch;
      final int latency = (now - serverTimestamp).clamp(0, 5000);
      final int calculatedPositionMs = isPlaying ? basePositionMs + latency : basePositionMs;

      final currentMs = _controller.value.position.inMilliseconds;
      if ((currentMs - calculatedPositionMs).abs() > 1000) {
        _controller.seekTo(Duration(milliseconds: calculatedPositionMs));
      }

      if (isPlaying && !_controller.value.isPlaying) {
        _controller.play();
      } else if (!isPlaying && _controller.value.isPlaying) {
        _controller.pause();
      }
    });
  }

  void _playerListener() {
    if (_controller.value.isReady && !_isPlayerReady) {
      setState(() => _isPlayerReady = true);
    }
  }

  void _updateHostPlayback(bool play) {
    if (!widget.isHost) return;
    _roomRef.update({
      'isPlaying': play,
      'positionMs': _controller.value.position.inMilliseconds,
      'timestamp': ServerValue.timestamp,
    });
  }

  void _changeTrack() {
    final input = _urlController.text.trim();
    final videoId = YoutubePlayer.convertUrlToId(input) ?? input;
    if (videoId.isNotEmpty && widget.isHost) {
      _roomRef.update({
        'videoId': videoId,
        'isPlaying': true,
        'positionMs': 0,
        'timestamp': ServerValue.timestamp,
      });
      _controller.load(videoId);
      _urlController.clear();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Room: ${widget.roomCode} (${widget.isHost ? "Host" : "Listener"})'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            YoutubePlayer(
              controller: _controller,
              showVideoProgressIndicator: true,
              progressColors: const ProgressBarColors(
                playedColor: Colors.amber,
                handleColor: Colors.amberAccent,
              ),
            ),
            const SizedBox(height: 20),
            if (widget.isHost) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _urlController,
                        decoration: const InputDecoration(
                          hintText: 'Paste YouTube Song URL/ID',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _changeTrack,
                      child: const Text('Play Track'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.filled(
                    iconSize: 40,
                    icon: const Icon(Icons.play_arrow),
                    onPressed: () => _updateHostPlayback(true),
                  ),
                  const SizedBox(width: 20),
                  IconButton.filled(
                    iconSize: 40,
                    icon: const Icon(Icons.pause),
                    onPressed: () => _updateHostPlayback(false),
                  ),
                ],
              ),
            ] else ...[
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Connected as Listener. Playback is synchronized automatically with the host.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
