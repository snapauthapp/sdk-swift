//
//  File.swift
//  
//
//  Created by Eric Stern on 5/17/24.
//

import AuthenticationServices

#if os(macOS)
// TODO: this will probably crash if it tries to start with no window open (but also how could it?)
let defaultPresentationAnchor: ASPresentationAnchor = NSApplication.shared.mainWindow!
#else
let defaultPresentationAnchor: ASPresentationAnchor = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first?.rootViewController?.view.window ?? ASPresentationAnchor()
#endif
