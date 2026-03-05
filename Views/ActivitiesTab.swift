//
//  ActivitiesTab.swift
//  ActivTimer
//
//  Created by Katelyn on 1/16/26.
//

import SwiftUI
import UIKit
import SwiftData

struct PointsResult {
    let base: Int
    let bonus: Int
    var total: Int { base + bonus }
}

struct PointsEngine {
    func points(for activity: WorkoutActivity) -> PointsResult {
        // Base minutes by category:
        // - Mindfulness: 10
        // - Running/Walking: 45
        // - Strength/Flexibility (e.g., Push-Ups, Pull-Ups, Yoga, Stretches): 30
        let isMind = activity.isMindfulness
        let isWalk = activity.isWalking
        let isRun = activity.isRunning
        let isLL = activity.isLetterLegs

        let base: Int
        if isMind {
            // Mindfulness: short guided breaks
            base = 10
        } else if isRun {
            // Running: longer cardio
            base = 45
        } else if isWalk {
            // Walking: align with Running award
            base = 45
        } else if isLL {
            // Strength/Flexibility (Letter Legs and similar)
            base = 30
        } else {
            // Default strength/core
            base = 30
        }

        let bonus = 0

        return PointsResult(base: base, bonus: bonus)
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

fileprivate extension WorkoutActivity {
    var isMindfulness: Bool {
        systemImageName.contains("lungs") ||
        title.localizedCaseInsensitiveContains("Breathing") ||
        title.localizedCaseInsensitiveContains("Meditation") ||
        title.localizedCaseInsensitiveContains("Gratitude")
    }
    var isWalking: Bool {
        systemImageName.contains("run") && title.localizedCaseInsensitiveContains("Walk") ||
        title.localizedCaseInsensitiveContains("Walking")
    }
    var isRunning: Bool {
        systemImageName.contains("run") && title.localizedCaseInsensitiveContains("Run") ||
        title.localizedCaseInsensitiveContains("Running")
    }
    var isLetterLegs: Bool {
        title.localizedCaseInsensitiveContains("Letter Leg") ||
        title.localizedCaseInsensitiveContains("Letter Legs")
    }
    // If you later store distance, expose it here; for now, nil
    var distanceKilometers: Double? { nil }
}

// Local vertical variable blur, scoped to ActivitiesTab only via modifier
private struct VerticalVariableBlur: ViewModifier {
    let maxRadius: CGFloat
    @State private var contentFrame: CGRect = .zero

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { contentFrame = proxy.frame(in: .named("ActivitiesVerticalScrollSpace")) }
                        .onChange(of: proxy.frame(in: .named("ActivitiesVerticalScrollSpace")).origin.y) {
                            contentFrame = proxy.frame(in: .named("ActivitiesVerticalScrollSpace"))
                        }
                }
            )
            .overlay(
                GeometryReader { outer in
                    let visible = outer.frame(in: .named("ActivitiesVerticalScrollSpace"))
                    let contentCenterY = contentFrame.midY
                    let visibleCenterY = visible.midY
                    let distance = abs(contentCenterY - visibleCenterY)
                    let halfHeight = max(visible.height / 2, 1)
                    let normalized = min(max(distance / halfHeight, 0), 1)
                    let radius = normalized * maxRadius

                    Color.clear
                        .allowsHitTesting(false)
                        .blur(radius: radius)
                        .blendMode(.normal)
                }
            )
    }
}

private extension View {
    func verticalVariableBlur(maxRadius: CGFloat) -> some View {
        modifier(VerticalVariableBlur(maxRadius: maxRadius))
    }
}

struct WorkoutActivity: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let color: Color
    let systemImageName: String // Thumbnail in menu uses SF Symbol
    let gifName: String?        // Optional GIF shown in expanded/prompt view
    let mediaName: String?      // Static image asset name shown if no gif available
    let description: String
}

// SF Symbols for thumbnails; use gifName for the expanded prompt animation when available.
private let yogaAndStretches: [WorkoutActivity] = [
    .init(title: "Letter Leg Stretch", color: .green, systemImageName: "figure.yoga", gifName: "robloxian_letterlegs.gif", mediaName: nil, description: """
For each of these five moves, hold them for 5-10 breaths or 30 seconds to a minute. Repeat them for the opposite leg and perform two sets of each move.

Step 1 — Warrior 3 / Arabesque: Start in a Warrior 3 or Arabesque pose, forming a “Y” with your body. Begin from the mountain position and transition into a lunge position. Stand on one leg and extend the other leg back horizontally. Hover it by lifting your other leg in the air. Shift your core strength and weight forward, and airplane your arms out or by your sides. Keep your shoulders square and gaze forward at the wall as you balance and lean forward.

Step 2 — Next, create a “K” by performing a lower leg standing calf stretch. Extend one leg out and point the foot upward. Bend your other knee slightly, bearing weight on it.

Step 3 — Then, curl into a “B” by continuing on the standing calf stretch. Transition into a Warrior 1 pose by bending the front leg. Maintain the standing calf stretch position by bending the front knee while keeping the back leg straight, with your arms by your sides.

Step 4 — Create an “T” by stretching into a Warrior 2. Return to the neutral mountain position and step the back foot 3-4 feet behind you with a straight leg. Angle your foot outward by 15 degrees. With your front foot, align it with the heel of the back foot at a 90-degree angle (12 o’clock position). Airplane your arms straight by your sides and lunge the front leg forward. Keep your torso facing the side where your back foot is facing. Maintain a steady gaze forward and shoulders softly centered. Press your feet into the mat while performing this pose.

Step 5 - Finally, do the Warrior 1 pose to turn your legs into an “A.” Return to the mountain pose and get into a runner or low lunge position. Like in Warrior 2, instead of angling the back foot 15 degrees, do it 45 degrees. Keep your torso facing forward and gaze forward, similar to a high lunge, but keep both feet planted. Raise your arms straight up in the air with your core engaged and hips squared. 
"""),
    .init(title: "Full and Half Splits", color: .teal, systemImageName: "figure.gymnastics", gifName: "FullSplits_Roblox.gif", mediaName: nil, description: """
Before attempting the front split, let’s start with a half split. Remember to warm up with a workout in the Cardio/Workout section to get your legs pumped and muscles ready. 
Half Split: Begin in a low lunge position with the right leg forward and the back knee resting on the floor. Rest your fingertips on the floor. As you extend the right leg forward, move your hands back. Rest the right heel on the floor and flex your foot. Try to keep your hips aligned with the back knee. Exhale and fold your torso forward. Breathe while holding the pose for 30 seconds. Inhale and release. Repeat the stretch on the reverse leg. 
Front Splits: Begin in a low, deep lunge position. From kneeling, slide one foot forward into a lunge. Stack your front knee over your ankle and keep your back knee behind your hip. Stay upright and brace your core. 
Slide into the Split: Slowly straighten both knees while allowing your front heel to slide forward and your back leg to slide behind. Keep your hips square by guiding your back hip forward. 
Check Alignment/Form: Ensure that your front kneecap faces up, your back kneecap faces down, and both legs remain straight with your hips level. Keep your hips square, your legs straight, and your toes pointed. Avoid leaning back or arching your spine. Hold the stretch for 20–30 seconds, breathing deeply. Exit the stretch slowly to avoid straining your muscles.
"""),
    .init(title: "Arm Circles", color: .mint, systemImageName: "figure.cooldown", gifName: "robloxian_armcircles.gif", mediaName: nil, description: """
        Arm circles are a versatile exercise that targets the shoulders, arms, and upper back. They can be performed anywhere, making them a convenient addition to your workout routine. To enhance their effectiveness, vary the size of the circles and increase the speed.
        Here’s how to perform arm circles: 1. Start by sitting or standing with your feet shoulder-width apart and your arms spread out on each side, at shoulder height.
        2. Begin by moving your arms in small circular motions, performing 15 to 20 repetitions of forward circles.
        3. Next, switch to backward circles and repeat the same number of repetitions (15 to 20).
        4. After completing the forward and backward circles, bring both arms down to your sides and rest for 10 seconds.
        5. Repeat the entire circuit for 2 to 4 more sets. By incorporating arm circles into your routine, you can effectively strengthen and stretch your shoulders, arms, and upper back.
        """
   ),
    .init(title: "Strengthening Warrior 1", color: .orange, systemImageName: "figure.flexibility.circle.fill", gifName: "robloxian_warrior1.gif", mediaName: nil, description: """
    Begin in Mountain Pose. Step your left foot back about 3–4 feet while keeping your front foot pointed forward. Turn your back foot out about 45–60 degrees, grounding through the outer edge. 
    Bend your front knee directly over the ankle, forming a 90-degree angle. Square your hips toward the front of the mat (this may require adjusting the back foot to maintain stability). 
    Inhale to lift your arms overhead straight up, palms facing each other or touching. Keep your shoulders relaxed and ribs drawn in as you lengthen your spine. If comfortable, gaze forward or slightly upward. 
    Hold this position for 5–10 breaths, about 30 seconds to 1 minute per side, then step forward and repeat on the opposite side. Repeat this sequence for 2–3 more sets."
    """),
    .init(title: "Focused Warrior 2", color: .green, systemImageName: "figure.pilates", gifName: "robloxian_warrior2.gif", mediaName: nil, description: """
        Begin in Mountain Pose. Step your left foot back about 3–4 feet, turning it out to a 90-degree angle. Align the front heel with the arch of the back foot. 
        Bend your front knee directly over your ankle, forming a 90-degree angle. Extend your arms out to the sides at shoulder height, palms facing down. Keep your torso upright and centered over your hips. 
        Gaze over your front fingertips, maintaining a long neck and soft shoulders. Press into both feet and engage your legs fully. 
        Hold this position for 5–10 breaths, approximately 30 seconds to 1 minute per side, then step forward and repeat on the opposite side. Continue this sequence for 2–3 more sets.
        """),
    .init(title: "Energizing Warrior 3", color: .teal, systemImageName: "figure.flexibility", gifName: "robloxian_warrior3.gif", mediaName: nil, description: """
        An energizing and graceful one-leg balance, with various forms. The main difference between Arabesque and Warrior III one-leg balance pose is that Arabesque is a ballet/gymnastics position where the dancer or gymnast stands on one leg and extends the other leg behind them, while Warrior III is a yoga pose where the dancer stands on one leg and bends forward, extending the other leg back.
        1. Start in Mountain Pose: Stand with both legs together, feet close, and ensure your hips and shoulders are square.
        2. Balance Support: Extend your arms out to the sides, parallel to the ground, like an airplane, to help maintain balance.
        3. Shift Weight: Transfer your weight onto the supporting leg.
        4. Raise the Leg: Engage your core and lift the opposite leg behind you and upward. Point your toes and slightly rotate your hip outward. Keep your gaze forward.
        5. Hold the Pose: Maintain this position for 25-30 seconds, which is approximately 10 breaths. Face to the side of where your back foot is pointing towards.
        6. Adjust as Needed: Continue raising the leg until you begin to lose form. Return to the starting position.
        7. Repeat on the Other Side: Switch legs and repeat the pose.
        8. Complete Sets: Perform the entire sequence for 1-2 more sets. 
        """)
]

private let strengthCardioCore: [WorkoutActivity] = [
    .init(title: "Dumbell Push Press", color: .orange, systemImageName: "figure.strengthtraining.traditional", gifName: "robloxian_pushpress.gif", mediaName: nil, description: """
 Grab a pair of medium to heavy dumbbells, approximately 5-10 pounds. 
 Stand with your feet shoulder-width apart. Hold two dumbbells at shoulder height with your elbows bent and palms facing away. 
 Press the dumbbells overhead until your elbows are fully extended. 
 Squeeze the contraction, then slowly return the weights to the starting position. 
 Repeat this for 10-20 reps per set, and perform 2 more sets. Ensure your back and core are stable, and your hips are straight throughout the exercise.
 """),
    .init(title: "Push-Ups", color: .indigo, systemImageName: "figure.strengthtraining.functional", gifName: "robloxian_pushups.gif", mediaName: nil, description: """
        Push-ups demand coordination, control, and strength from your chest, shoulders, triceps, and core simultaneously. Here’s how to perform a modified pushup and a full pushup with knees on and off the floor.

        Modified Pushups: These push-ups teach your body the full range of motion required for a traditional push-up. They also build endurance in your stabilizing muscles, which is crucial for progress.
        
        Start in a plank position with your knees on the ground, positioned underneath your hips. Place your hands shoulder-width apart. Engage your core and lower your chest toward the floor in a controlled motion. Press back up, maintaining tension in your chest, shoulders, and core throughout.
        
        Full Pushups: Once you can perform traditional push-ups with control, you’re building significant functional strength that translates into everyday life, whether you’re pushing open a heavy door or lifting yourself from the floor. This classic move is the pinnacle of push-up training, and by the time you reach it, you’ll have developed the strength and control to execute it correctly.
        
        Start in a high plank position with hands slightly wider than shoulder-width and feet hip-width apart. Keep your body in a straight line from head to heels by engaging your core and glutes. Lower your chest toward the floor in a slow, controlled motion. Press through your palms to return to the starting position without letting your hips sag or your back arch.
        
        Repeat one of these variations for 10-20 reps per set, for 2-3 sets. 

        """),
    .init(title: "Pull-Ups", color: .red, systemImageName: "figure.play", gifName: "pullups.gif", mediaName: nil, description: """
        Pullups are an impressive display of upper-body strength. They require a pull-up machine, monkey bars, or an overhead bar at a gym, playground, or any place with fitness equipment. The main muscles involved are the back (specifically the rhomboids and lats), arm muscles (including the posterior deltoids and biceps), and the core. Pullups are a common upper-body strength workout done at gyms or anywhere with an overhead bar or pull-up machine.

        You can either jump up to grab the bars or place a bench or chair in front of them (Some pull up machines even have a moving platform for you to get up on them easily). Then, grab the bars and bend your knees, crossing your ankles so you’re in a hanging position. Engage your core, use your arms and back to pull your body up toward the bar, lifting your chin over it. Think about pulling your elbows down and into your ribcage. Slowly lower yourself back down to hanging and repeat.

        Repeat for 10 reps per set for 2-3 sets. 
        """),
    .init(title: "Running", color: .pink, systemImageName: "figure.run", gifName: "robloxian_running.gif", mediaName: nil, description: """
        Running is an incredibly simple exercise that can help build cardio endurance, improve overall fitness, and even get your heart pumping.

        Outdoor: If the weather is nice, find a local park, the sidewalk, or join a run club like the Nike Run Club app, which is a great resource.
        
        Indoor: If you don’t have access to a nice route to run outside or the weather isn’t suitable, or if you prefer a treadmill, you can substitute the outdoor run ideas with treadmill workouts. Just adjust the speed and incline accordingly when prompted to slow down, pick up the pace, and/pr increase your effort. Nike Run Club and Apple Fitness+ offer many treadmill-specific workouts.
        
        Here are a few run ideas that can help you get up for a great screen time break, however long you need:
        1. Easy Run with Strides (Perfect for Beginners): Let’s start with the easiest type of running workout: an easy run that ends with strides. Running at a slow speed, like a 3 out of a 10 effort and pace, increases endurance, encourages proper running form, builds a routine, establishes base mileage, and also aids recovery.
        
        This type of run should be your most common one, accounting for about 65-80% of your total mileage (monthly).
        
        Your easy runs should be runs where you stay within heart-rate zones 1 and 2, which is about under 145 beats per minute (varies by age).
        
        This is when you can comfortably keep a conversation going and speak in full sentences without running out of breath, which is conversational pace.

        2. Tempo Run: Tempo runs are an important type of running workout that can help improve your speed and endurance. The pace of the tempo run is sometimes described as “comfortably challenging.”

        They are difficult enough to need pushing (at a 6 out of a 10 effort rate), yet comfortable enough to allow you to keep going.
        
        This is often approximately 85-90% of your maximum heart rate, or slightly slower than your 10K race pace. It’s where brief sentences are doable, but a full-fledged conversation definitely isn’t.
        We conduct tempo sessions to enhance our lactate threshold, the point at which our body transitions from its aerobic to anaerobic systems, leading to rapid fatigue.
        
        Here’s a template for a 1-hour tempo run: Begin with easy warm-up miles, then run for 20 minutes at tempo pace, followed by easy cool-down miles. Another option is to begin with easy warm-up miles, run for 20 minutes at tempo pace, then for 10 minutes at an easy pace, followed by another 20 minutes at tempo pace, and finally, easy cool-down miles.
        
        3. Fartlek Workout: The Swedish word “fartlek” translates to “speed play,” which perfectly describes this workout. It allows you to experiment with varying speeds and distances within the same session.
        
        Fartlek is an excellent way to introduce speedwork training. It’s ideal for beginners who want to experience speedwork before diving in fully.
        
        This type of speed training is quite straightforward. Simply alternate between running fast and running slow, varying the distance and pace of each interval.
        
        Here are some ideas to try: a 3-mile run with 5 x 30 seconds of hard effort (not exceeding 9/10 or higher effort!), a 5-mile run with 10 x 1-minute hard effort, and a 6-mile run with 7 x 1-minute increasingly hard effort.
        """),
    .init(title: "Mindful Walk", color: .purple, systemImageName: "figure.run", gifName: "robloxian_walking.gif", mediaName: nil, description: """
        Walking is a wonderful way to blend mindfulness with cardio fitness. If you’re near a park or river, try walking there for fewer distractions. 
        If not, a treadmill or backyard works too. You can even play nature videos or listen to music on your iPhone, iPad or the Apple TV to mimic the environment.
        
        Here’s a quick guide:
        
        1. As you start walking, notice how your body feels. Is it heavy or light? Take a moment to check your posture/form.
        2. Observe your walking without changing it. It’s normal to feel self-conscious, but it passes quickly.
        3. If you’re outside: Stay aware of your surroundings—cars, people, signals.
        4. Look around and notice colors, shapes, and movements for about 30 seconds.
        5. Listen to the sounds around you for another 30 seconds.
        6. Focus on smells for 30 seconds, noticing pleasant or unpleasant ones.
        7. Feel physical sensations like sunshine or the ground beneath your feet for 30 seconds.
        8. Let things come and go in your awareness without judgment.
        9. After a minute or two, pay attention to your body’s movement and rhythm.
        10. Use the rhythm of your steps as a mental anchor.
        11. Stay open to your surroundings and gently bring your focus back to your steps if your mind wanders.
        12. Notice your mental habits, like impatience at a red light, and observe your reactions.
        """),
    .init(title: "Crunches", color: .blue, systemImageName: "figure.core.training", gifName: "robloxian_situps.gif", mediaName: nil, description: """
        The crunch is a classic core exercise that specifically targets your abdominal muscles, which are a crucial part of your core. Your core encompasses not only your abs but also your oblique muscles on the sides of your trunk, as well as the muscles in your pelvis, lower back, and hips. These muscles work together to provide stability to your body.

        The standard crunch is performed on the floor. For added comfort, you can do it on an exercise or yoga mat.

        To perform a crunch, lie down on your back with your feet planted firmly on the floor, hip-width apart. Bend your knees and place your arms across your chest. Engage your abdominal muscles and inhale. Exhale and lift your upper body, ensuring that your head and neck remain relaxed. Inhale and return to the starting position.
        Repeat this exercise for 10-20 repetitions, performing 2-3 sets. 
        """)
]

private let mindfulness: [WorkoutActivity] = [
    .init(title: "Star Breathing", color: .blue, systemImageName: "star.fill", gifName: "star_breathing.gif", mediaName: nil, description: """
        A ‘breathing star’ is a simple visual tool that aids individuals in focusing on taking deep breaths. It can be employed to alleviate stress or anxiety, or simply to facilitate a state of relaxation. This activity is particularly beneficial after brain breaks and provides a brief respite from screens, accompanied by visualization. It helps individuals prepare their bodies and minds for learning and mindful thinking.

        The star comprises five points, each symbolizing a breath. Engage in this deep breathing technique to calm down.
        
        Select any point of the star visible in the image to commence.
        Exhale (inhalation) for a count of three, holding the breath for a count of three.
        Inhale (exhalation) for a count of three.
        Continue breathing deeply around the entire star until you return to the starting point.
        Repeat the process as necessary, for a duration of five to ten minutes for this session.

        """),
    .init(title: "Balanced Breathing", color: .cyan, systemImageName: "waveform.path.ecg", gifName: "balanced_breathing.gif", mediaName: nil, description: """
        Deep breathing is often one of the first, common relaxation techniques we turn to when we need to get our tension or stress under control.
        We know that when we slow down our breathing rate and take deep, slow breaths, we immediately start feeling the benefits of this easy and useful technique.
        Think of deep breathing as the pause button for a revved-up brain. When people get hit with stress, anxiety, or any big feeling, their bodies flip into “fight-or-flight” mode. This floods their system with stress hormones and makes it nearly impossible to think straight.
        
        Taking a slow, intentional breath is like hitting the brakes on that response. It activates the body’s natural relaxation system, sending a clear signal to the brain that everything is okay. The heart rate slows, muscles begin to unclench, and their mind starts to clear.
        
        Even excessive content consumption and endless/mindless browsing and distraction can lead to our minds being overwhelmed. Let’s practice a 4-7-8 breathing technique so you can earn your way to getting back to being yourself after this mindful break. Press the next button to start. 
        
        Quietly breathe in through the nose for a count of four.
        Hold that breath for a count of seven.
        Exhale slowly and completely through the mouth for a count of eight.

        """),
    .init(title: "Ocean Breaths", color: .indigo, systemImageName: "lungs.fill", gifName: "ocean_breathing.gif", mediaName: nil, description: """
        Ocean Breath helps you focus and channel your breath, giving asana practice a boost in power and concentration. It also helps you breathe more deeply.

        Practicing this breathing pattern can also help calm your body’s “fight or flight” response, promoting relaxation.

        Sit up straight with your shoulders relaxed and away from your ears. Close your eyes and become aware of your breath without trying to control it. If you’ve been breathing through your nose, start inhaling and exhaling through your mouth.

        Bring your attention to your throat. On your exhales, gently tone the back of your throat (your larynx), similar to fogging up a pair of glasses. You should hear a soft hissing sound.

        Once you’re comfortable with the exhale, try to apply the same throat contraction to your inhales. You should hear another soft hissing sound. That’s where the name of the breath comes from—it sounds like the deep sea ocean like the picture! (It also sounds like a steam engine.)

        When you can control the throat on both the inhale and the exhale, close your mouth and start breathing through your nose. Continue applying the same throat toning that you did when your mouth was open. The breath will still make a noise coming in and out of your nose. That’s ujjayi breath.
        """),
    .init(title: "Body Scan Meditation", color: .mint, systemImageName: "figure", gifName: "body_scan.gif", mediaName: nil, description: """
        Body scan meditation is an accessible meditation technique that helps reconnect with your body and calm your mind.

        This simple mindfulness practice involves bringing gentle, nonjudgmental awareness to different parts of your body, from head to toe. It’s perfect for winding down, resetting from screens, and more.

        Stress can manifest in the body before you even notice it in your mind, through headaches, tight shoulders, back pain, or fatigue. Body scan meditation helps bring these signals to light.

        By mentally scanning yourself from top to bottom—often visualized like a giant laser or copy machine slowly moving down the body—you build awareness of physical sensations, including discomfort, tension, or areas of ease.

        The goal is not to change anything but to simply notice what’s there with openness and care. Here are the instructions, and watch the glorious forest scene on the screen as you follow it step by step.

        Sit comfortably and take a deep breath in through your nose and out through your mouth. As you exhale, gently close your eyes.

        Start at the top of your head and begin scanning down through your body. Notice how each part feels—relaxed or tense, light or heavy, comfortable or uncomfortable. You’re not trying to change anything; you’re simply becoming aware. Continue down through your shoulders, arms, chest, stomach, hips, legs, and finally, your feet.

        Let each breath support your attention. If your mind wanders, gently bring it back to wherever you left off.
        """),
    .init(title: "Gratitude", color: .green, systemImageName: "heart.text.square", gifName: "gratitude.gif", mediaName: nil, description: """
        Studies have shown that feeling grateful is linked to a happier and more fulfilling life. These studies suggest that keeping a gratitude journal can boost our optimism, ease depression, strengthen our immune system, and lower blood pressure. Plus, it helps us connect better with those around us.

        If appreciating kindness, beauty, and the things that bring us joy makes us happier, why not make it a daily habit, like Americans do with Thanksgiving? You can practice gratitude anytime, anywhere. Treat yourself with some self-love and self-care.
        
        Here are a few affirmations you can read as you watch this beautiful waterfall cascade on your screen. Ready? Tap the next button to start.
        
        Gratitude brightens my day.
        
        Gratitude fills my heart with love and joy.
        
        Being thankful helps me find treasure in every day.
        
        Every day is a new opportunity.
        
        I reflect, learn, and step forward into greatness.
        
        You can also practice affirmations daily, keep a journal on the Journal app on iPhone, and even explore quotes to enhance your mindfulness and strengthen ethical screen time over social media feeds. 
        """),
    .init(title: "Box Breathing", color: .teal, systemImageName: "shippingbox", gifName: "box_breathing.gif", mediaName: nil, description: """
        It is a common breathing and mindfulness exercise, is widely used to manage anxiety and stress. It’s performed in a sequence resembling a square box, creating rhythmic stability that balances the sympathetic and parasympathetic nervous systems, promoting calm alertness.

        Inhale slowly through the nose, counting to 4. Hold your breath for a count of 4. Exhale gently for a count of 4. Hold again for a count of 4 before the next inhalation. Repeat this square cycle several times, with a duration of 3-5 minutes.
        """)
]

struct ActivitiesTab: View {
    @Environment(\.modelContext) private var context
    @Query private var pointsList: [Points]

    @AppStorage("appThemeName") private var appThemeName: String = "Default"

    private let cardWidth: CGFloat = 300
    private let cardHeight: CGFloat = 200

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    @Namespace private var activityNS
    @State private var expanded: Bool = false
    @State private var selectedTitle: String? = nil
    @State private var selectedActivity: WorkoutActivity? = nil
    @State private var isCelebrating: Bool = false
    
    @State private var showCompletionToast: Bool = false
    @State private var lastAwardSummary: String = ""

    private enum WorkoutCategory {
        case mindfulness
        case flexibility   // yoga, stretches, gymnastics
        case strength      // weights, pushups, pullups, core
        case cardio        // running, walking
    }

    private func category(for activity: WorkoutActivity) -> WorkoutCategory {
        // Map based on known sections or heuristics by symbol/title
        if activity.systemImageName.contains("lungs") || activity.title.localizedCaseInsensitiveContains("Breathing") || activity.title.localizedCaseInsensitiveContains("Meditation") || activity.title.localizedCaseInsensitiveContains("Gratitude") {
            return .mindfulness
        }
        if activity.systemImageName.contains("flexibility") || activity.systemImageName.contains("yoga") || activity.systemImageName.contains("pilates") || activity.title.localizedCaseInsensitiveContains("Warrior") || activity.title.localizedCaseInsensitiveContains("Split") ||
            activity.title.localizedCaseInsensitiveContains("Arm Circles") ||
            activity.title.localizedCaseInsensitiveContains("Stretch") {
            return .flexibility
        }
        if activity.systemImageName.contains("run") || activity.title.localizedCaseInsensitiveContains("Run") || activity.title.localizedCaseInsensitiveContains("Walk") {
            return .cardio
        }
        return .strength
    }

    private func isLongWorkout(_ activity: WorkoutActivity) -> Bool {
        // Heuristic/Filtering: treat titles mentioning a run  long/tempo/fartlek/etc. as long; otherwise short
        let t = activity.title.lowercased()
        return t.contains("long") || t.contains("tempo") || t.contains("fartlek")
    }

    private func awardFor(activity: WorkoutActivity) {
        let engine = PointsEngine()
        let result = engine.points(for: activity)

        // Use shared singleton Points via @Query; create if missing
        let pointsModel: Points
        if let existing = pointsList.first {
            pointsModel = existing
        } else {
            let p = Points()
            context.insert(p)
            pointsModel = p
        }

        // Minutes for break timer equals total points per your rule
        pointsModel.screenTimeBalanceMinutes += result.total
        pointsModel.total += result.total
        do {
            try context.save()
        } catch {
            print("Failed to save award: \(error)")
        }
        
        // Prepare and show completion toast
        let minutesAwarded = result.total
        let workoutName = activity.title
        lastAwardSummary = "+\(minutesAwarded) min — \(workoutName) completed"
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            showCompletionToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeInOut) {
                showCompletionToast = false
            }
        }
    }
    

    var body: some View  {
        NavigationStack {
            ZStack {
                Group {
                    if appThemeName == "Cosmic Orange" {
                        Color.clear
                    } else {
                        Color.blue.opacity(0.15)
                    }
                }
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // Visible green titles on sections 
                        Text("Workout Breaks")
                            .font(.largeTitle.bold())
                            .foregroundColor(.green)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                            .padding(.top, 6)


                        // Section 1: Yoga & Quick Stretches
                        SectionHeader(title: "Yoga & Quick Stretches")
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(alignment: .top, spacing: 12) {
                                ForEach(yogaAndStretches) { item in
                                    Button {
                                        selectedTitle = item.title
                                        selectedActivity = item
                                        expanded = true
                                    } label: {
                                        ActivityCard(activity: item)
                                            .frame(width: cardWidth, height: cardHeight)
                                            .matchedTransitionSource(id: "ActivityCard-\(item.id.uuidString)", in: activityNS)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal)
                        }

                        // Section 2: Strength, Cardio & Core
                        SectionHeader(title: "Strength, Cardio & Core")
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(alignment: .top, spacing: 12) {
                                ForEach(strengthCardioCore) { item in
                                    Button {
                                        selectedTitle = item.title
                                        selectedActivity = item
                                        expanded = true
                                    } label: {
                                        ActivityCard(activity: item)
                                            .frame(width: cardWidth, height: cardHeight)
                                            .matchedTransitionSource(id: "ActivityCard-\(item.id.uuidString)", in: activityNS)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal)
                        }

                        // Section 3: Mindfulness Strategies
                        SectionHeader(title: "Mindfulness Strategies")
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(alignment: .top, spacing: 12) {
                                ForEach(mindfulness) { item in
                                    Button {
                                        selectedTitle = item.title
                                        selectedActivity = item
                                        expanded = true
                                    } label: {
                                        ActivityCard(activity: item)
                                            .frame(width: cardWidth, height: cardHeight)
                                            .matchedTransitionSource(id: "ActivityCard-\(item.id.uuidString)", in: activityNS)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .verticalVariableBlur(maxRadius: 10)
                }
                .coordinateSpace(name: "ActivitiesVerticalScrollSpace")
                
                // Confetti overlay owned by ActivitiesTab
                ConfettiView(isAnimating: $isCelebrating)
                    .allowsHitTesting(false)
                
                if showCompletionToast {
                    VStack {
                        Spacer()
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.seal.fill")
                                .imageScale(.large)
                                .foregroundStyle(.white)
                            Text(lastAwardSummary)
                                .foregroundStyle(.white)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.black.opacity(0.85))
                        )
                        .padding(.bottom, 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    .allowsHitTesting(false)
                }
            }
            .onAppear {
                let names = (yogaAndStretches + strengthCardioCore + mindfulness).compactMap { $0.gifName }
                GIFLoader.shared.preload(names: names)
                
                // Ensure a Points singleton exists so both tabs observe the same record
                if pointsList.isEmpty {
                    let p = Points()
                    context.insert(p)
                    try? context.save()
                }
            }
            .sheet(isPresented: $expanded) {
                ExpandedContent(
                    isExpanded: $expanded,
                    title: selectedTitle ?? "Workout",
                    mediaFilename: selectedActivity?.gifName ?? selectedActivity?.mediaName ?? "",
                    description: selectedActivity?.description ?? "",
                    onCompleted: {
                        if let act = selectedActivity {
                            awardFor(activity: act)
                        }
                        // Fire confetti on ActivitiesTab when user completes
                        isCelebrating = true
                        // Stop confetti after a short celebratory burst
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.75) {
                            isCelebrating = false
                        }
                    }
                )
                .navigationTransition(.zoom(sourceID: "ActivityCard-\(selectedActivity?.id.uuidString ?? "")", in: activityNS))
            }
        }
    }
}

struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.title2.bold())
            .foregroundColor(.green)
            .padding(.top, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
    }
}

struct ActivityCard: View {
    let activity: WorkoutActivity

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(activity.color.opacity(0.25))
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.6), lineWidth: 0.5)
                    .blendMode(.overlay)

                mediaView
            }
            .frame(height: 140)

            Text(activity.title)
                .font(.system(size: 15))
                .foregroundColor(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.001))
        )
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
        
    }
    
    @ViewBuilder
    private var mediaView: some View {
        // Thumbnails always show SF Symbol; GIFs are shown only in the expanded view
        Image(systemName: activity.systemImageName)
            .font(.system(size: 48, weight: .semibold))
            .foregroundStyle(activity.color)
    }
}

struct ActivityExpandedMediaView: View {
    let activity: WorkoutActivity

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private var content: some View {
        if let gif = activity.gifName, !gif.isEmpty, gifResourceExists(named: gif) {
            GifView(name: gif)
        } else if let gif = activity.gifName, !gif.isEmpty {
            placeholder
                .onAppear {

                    print("[ActivityExpandedMediaView] GIF not found or unreadable: \(gif)")

                }
        } else if let name = activity.mediaName, !name.isEmpty {
            Image(name)
                .resizable()
                .scaledToFit()
        } else {
            placeholder
        }
    }

    @ViewBuilder
    private var placeholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(activity.color.opacity(0.12))
            Image(systemName: activity.systemImageName)
                .font(.system(size: 64, weight: .semibold))
                .foregroundStyle(activity.color)
        }
    }

    private func gifResourceExists(named name: String) -> Bool {
        let ns = name as NSString
        if ns.pathExtension.isEmpty {
            return Bundle.main.url(forResource: name, withExtension: "gif") != nil
        } else {
            return Bundle.main.url(forResource: ns.deletingPathExtension, withExtension: ns.pathExtension) != nil
        }
    }
}


#Preview {
    ContentView()
}

