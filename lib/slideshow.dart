import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'shell.dart';

class SlideshowPage extends StatefulWidget {
  final VoidCallback onFinish;
  const SlideshowPage({super.key, required this.onFinish});

  @override
  State<SlideshowPage> createState() => _SlideshowPageState();
}

class _SlideshowPageState extends State<SlideshowPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<SlideData> _slides = [
    SlideData(
      title: 'Welcome to Fit24',
      subtitle: 'Experience the next generation of fitness tracking.',
      videoUrl: 'assets/videos/intro.mp4',
      isVideo: true,
    ),
    SlideData(
      title: 'Track Your Moves',
      subtitle: 'Real-time GPS tracking for all your activities.',
      imageUrl: 'https://images.unsplash.com/photo-1476480862126-209bfaa8edc8?q=80&w=1000',
    ),
    SlideData(
      title: 'Earn Rewards',
      subtitle: 'Convert every step into Fit Points and level up.',
      imageUrl: 'https://images.unsplash.com/photo-1552674605-db6ffd4facb5?q=80&w=1000',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBody: true,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: _slides.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (context, i) => _SlideView(data: _slides[i]),
          ),

          // ── Indicators ─────────────────────────────────────────────────────
          Positioned(
            bottom: 120, left: 0, right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_slides.length, (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _currentPage == i ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _currentPage == i ? kGreen : Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(100),
                ),
              )),
            ),
          ),

          // ── Bottom Action ──────────────────────────────────────────────────
          Positioned(
            bottom: 40, left: 24, right: 24,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: widget.onFinish,
                  child: Text('Skip', style: TextStyle(color: Colors.white.withOpacity(0.5))),
                ),
                GestureDetector(
                  onTap: () {
                    if (_currentPage < _slides.length - 1) {
                      _pageController.nextPage(duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
                    } else {
                      widget.onFinish();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    decoration: BoxDecoration(
                      gradient: kGreenGrad,
                      borderRadius: BorderRadius.circular(100),
                      boxShadow: [BoxShadow(color: kGreen.withOpacity(0.3), blurRadius: 15)],
                    ),
                    child: Text(
                      _currentPage == _slides.length - 1 ? 'Get Started' : 'Next',
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SlideData {
  final String title;
  final String subtitle;
  final String? videoUrl;
  final String? imageUrl;
  final bool isVideo;
  SlideData({required this.title, required this.subtitle, this.videoUrl, this.imageUrl, this.isVideo = false});
}

class _SlideView extends StatefulWidget {
  final SlideData data;
  const _SlideView({required this.data});

  @override
  State<_SlideView> createState() => _SlideViewState();
}

class _SlideViewState extends State<_SlideView> {
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    if (widget.data.isVideo && widget.data.videoUrl != null) {
      if (widget.data.videoUrl!.startsWith('assets/')) {
        _videoController = VideoPlayerController.asset(widget.data.videoUrl!);
      } else {
        _videoController = VideoPlayerController.networkUrl(Uri.parse(widget.data.videoUrl!));
      }
      
      _videoController!.initialize().then((_) {
        _videoController!.setLooping(true);
        _videoController!.play();
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Background
        Positioned.fill(
          child: widget.data.isVideo
              ? (_videoController != null && _videoController!.value.isInitialized
                  ? FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _videoController!.value.size.width,
                        height: _videoController!.value.size.height,
                        child: VideoPlayer(_videoController!),
                      ),
                    )
                  : Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(color: Colors.black),
                        const CircularProgressIndicator(color: kGreen),
                      ],
                    ))
              : Image.network(
                  widget.data.imageUrl!, 
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  alignment: Alignment.topCenter,
                ),
        ),
        
        // Gradient overlay
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black.withOpacity(0.1), Colors.black.withOpacity(0.9)],
              ),
            ),
          ),
        ),

        // Text Content
        Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.data.title, style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: Colors.white, height: 1.1)),
              const SizedBox(height: 16),
              Text(widget.data.subtitle, style: TextStyle(fontSize: 18, color: Colors.white.withOpacity(0.7), height: 1.5)),
              const SizedBox(height: 140), // Space for indicators/buttons
            ],
          ),
        ),
      ],
    );
  }
}
