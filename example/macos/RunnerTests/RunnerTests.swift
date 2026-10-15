import Testing

@testable import file_picker_darwin

/// Unit tests for the parts of the native implementation that do not depend
/// on a system picker, which tests cannot drive.
@Suite("PickOutcome")
struct PickOutcomeTests {
    @Test("Nothing picked is a cancellation")
    func nothingPicked() {
        let outcome = PickOutcome<String>.resolve(pickedCount: 0, loaded: [])
        guard case .cancelled = outcome else {
            Issue.record("Expected cancelled, got \(outcome)")
            return
        }
    }

    @Test("Every picked item loaded")
    func everythingLoaded() {
        let outcome = PickOutcome.resolve(pickedCount: 2, loaded: ["a", "b"])
        guard case .loaded(let items) = outcome else {
            Issue.record("Expected loaded, got \(outcome)")
            return
        }
        #expect(items == ["a", "b"])
    }

    // Picking items that cannot be loaded, such as iCloud only photos while
    // offline, must not look like a cancellation (#2248).
    @Test("Nothing loaded is a failure, not a cancellation")
    func nothingLoaded() {
        let outcome = PickOutcome<String>.resolve(pickedCount: 2, loaded: [])
        guard case .loadFailed = outcome else {
            Issue.record("Expected loadFailed, got \(outcome)")
            return
        }
    }

    @Test("Partial failures keep the loaded items")
    func partialFailure() {
        let outcome = PickOutcome.resolve(pickedCount: 3, loaded: ["a"])
        guard case .loaded(let items) = outcome else {
            Issue.record("Expected loaded, got \(outcome)")
            return
        }
        #expect(items == ["a"])
    }
}

@Suite("MediaRepresentation")
struct MediaRepresentationTests {
    // A Live Photo registers its bundle first. Loading that would bring the
    // paired video along with the still image (#2260).
    // As registered by a HEIC Live Photo, JPEG first.
    static let livePhotoTypes = [
        "com.apple.live-photo-bundle",
        "public.jpeg",
        "public.heic",
        "com.apple.private.photos.thumbnail.standard",
    ]

    @Test("A Live Photo loads its original still image, not its bundle")
    func livePhoto() {
        let identifier = MediaRepresentation.typeIdentifier(
            for: Self.livePhotoTypes)
        #expect(identifier == "public.heic")
    }

    @Test("The compatible mode loads the JPEG the picker transcodes to")
    func compatible() {
        let identifier = MediaRepresentation.typeIdentifier(
            for: Self.livePhotoTypes, preferringCompatible: true)
        #expect(identifier == "public.jpeg")
    }

    @Test("A JPEG photo loads as JPEG")
    func jpegOnly() {
        let identifier = MediaRepresentation.typeIdentifier(for: ["public.jpeg"])
        #expect(identifier == "public.jpeg")
    }

    @Test("A video loads as a video")
    func video() {
        let identifier = MediaRepresentation.typeIdentifier(
            for: ["com.apple.quicktime-movie"])
        #expect(identifier == "com.apple.quicktime-movie")
    }

    @Test("An item with no image or video falls back to any representation")
    func noMedia() {
        let identifier = MediaRepresentation.typeIdentifier(
            for: ["com.apple.live-photo-bundle", "com.example.unknown"])
        #expect(identifier == "public.item")
    }
}
