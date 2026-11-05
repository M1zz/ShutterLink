//
//  WatchDemo.swift
//  스크린샷용 데모 (DEBUG 전용): `-watchDemo main` · `-watchDemo countdown`
//  시뮬레이터에는 카메라도 짝지은 iPhone 도 없어서, 미리보기 자리에 아이폰 데모와 같은 그림(DemoScene)을 두고
//  카메라 상태만 채운다.
//

#if DEBUG
import Foundation

enum WatchDemo {
    static var status: RemoteStatus? {
        var status = RemoteStatus(zoom: 1, minZoom: 0.5, maxZoom: 10, faces: 5, tilt: 0)
        switch UserDefaults.standard.string(forKey: "watchDemo") {
        case "main":
            status.timerSeconds = 3
        case "countdown":
            status.timerSeconds = 3
            status.countdown = 2
        default:
            return nil
        }
        return status
    }
}
#endif
