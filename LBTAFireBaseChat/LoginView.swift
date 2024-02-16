//
//  ContentView.swift
//  LBTAFireBaseChat
//
//  Created by Saar Bibla on 12/27/23.
//

import SwiftUI
import Firebase
import FirebaseStorage

struct LoginView: View {
    
    let didCompleteLoginProcess: () -> ()
    
    @State private var isLoginMode = false
    @State private var emailAddress = ""
    @State private var emailPassword = ""
    @State private var isEmailValid : Bool = true
    @State private var showingEmailAlert = false
    @State private var shouldShowImagePicker = false
    @State private var shouldShowLoginWithGoogle = false
    @State private var allowMessageForwardingDefault = "N"
    @State private var userImage: UIImage?
    @Environment(\.colorScheme) var colorScheme
    
    
    var body: some View {
        NavigationView 
        {
            ScrollView 
            {
                Button("") {
                    showingEmailAlert = true
                }
                .alert(isPresented: $showingEmailAlert) {
                    Alert(title: Text("Invalid email address"), message: Text("\"\(emailAddress)\" is not a valid email"), dismissButton: .default(Text("Got it!")))
                }.font(.custom("San Francisco", size: 20))
                VStack {
                    
                    Picker(selection: $isLoginMode, label:
                            Text(".")) {
                        Text("Log In")
                            .tag(true)
                        Text("Create Account")
                            .tag(false)
                    }.pickerStyle(SegmentedPickerStyle())
                        .font(.custom("San Francisco", size: 20))
                    //                    .padding()
                    if !isLoginMode {
                        Button {
                            shouldShowImagePicker.toggle()
                        } label: {
                            VStack {
                                if let userImage = self.userImage {
                                    Image(uiImage: userImage)
                                        .resizable()
                                        .frame(width: 128, height: 128)
                                        .scaledToFill()
                                        .cornerRadius(64)
                                }else {
                                    
                                    Image(systemName: "person.fill")
                                        .font(.custom("San Francisco", size: 64))
                                        .padding()
                                }
                            }
                            .overlay(RoundedRectangle(cornerRadius: 64)
                                .stroke(Color.black, lineWidth: 3)
                                     )
                        }
                    }else {
                        Button {
                            
                        } label: {
                            Image(systemName: "person.fill.questionmark")
                                .font(.custom("San Francisco", size: 61))
                                .padding()
                        }
                    }
                    
                    
                    TextField("Email", text: $emailAddress, onEditingChanged: { (isChanged) in
                        if !isChanged {
                            if self.textFieldValidatorEmail(self.emailAddress) {
                                print("Email is valid")
                                self.isEmailValid = true
                            } else {
                                self.isEmailValid = false
                                print("Invalid email")
                                showingEmailAlert = true
                                emailAddress = ""
                            }
                        }
                    })
                    .padding(12)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    //                        .background(Color.white)
                    .background(Color(UIColor.systemBackground))
                    
                    .font(.custom("San Francisco", size: 20))
                    .onAppear {
                        UITextField.appearance().clearButtonMode = .whileEditing
                    }
                    SecureField("Password", text: $emailPassword)
                        .padding(12)
                    //                        .background(Color.white)
                        .background(Color(UIColor.systemBackground))
                        .font(.custom("San Francisco", size: 20))
                    
                    Button ( action: {handleAction()} ) {
                        Spacer()
                        Text(isLoginMode ? "Log In" : "Create Account")
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .font(.custom("San Francisco", size: 20))
                        Spacer()
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.roundedRectangle(radius: 8))
                 
                    if isLoginMode {
                            HStack{
                                Color.gray.frame(height: 1 / UIScreen.main.scale)
                                Text("Or")
                                Color.gray.frame(height: 1 / UIScreen.main.scale)
                            }

                        Button ( action: {shouldShowLoginWithGoogle.toggle()}) {
                            Text("Sign in with Google")
                                .foregroundColor(colorScheme == .dark ? .white : .black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .font(.custom("San Francisco", size: 20))
                                .background(alignment: .leading) {
                                    Image(colorScheme == .dark ? "Google" : "GoogleNoBackground")
                                        .frame(width: 30, alignment: .center)
                                }
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.roundedRectangle(radius: 8))
                    }
                    
                    Text(self.loginStatusMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                }
                .padding()
                
            }
            .navigationTitle(isLoginMode ? "Login" : "Create Account")
            .background(Color(.init(white: 0, alpha: 0.05))
                .font(.custom("San Francisco", size: 40))
//                .buttonBorderShape(.roundedRectangle(radius: 18))
                .ignoresSafeArea())
            
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .fullScreenCover(isPresented: $shouldShowImagePicker, onDismiss: nil, content: {
            ImagePicker(image: $userImage)
        })
        .fullScreenCover(isPresented: $shouldShowLoginWithGoogle, onDismiss: nil, content: {
            GamificationView()
        })
    }
    
    
    
    private func handleAction() {
        if emailAddress.isEmpty || emailPassword.isEmpty {
            print("Email and password can't be empty")
        } else {
            //confirm input
            
            if isLoginMode {
                print("Login to firebase with user:\(emailAddress) and pass:\(emailPassword)")
                loginUser()
            } else {
                print("Create account in firebase with user:\(emailAddress) and pass:\(emailPassword)")
                createNewAccount()
            }
        }
    }
    @State private var loginStatusMessage = ""
    
    private func loginUser() {
        FirebaseManager.shared.auth.signIn(withEmail: emailAddress, password: emailPassword) {
            result, err in
            if let err = err {
                print("Failed to login user:", err)
                self.loginStatusMessage = "Failed to login user: \(err)"
                return
            }
            print("Successfully logged in as user: \(result?.user.uid ?? "")")
            self.loginStatusMessage = "Successfully logged in as user: \(result?.user.uid ?? "")"
            self.didCompleteLoginProcess()
        }
        
    }
    
    
    
    private func createNewAccount() {
        if self.userImage == nil {
            self.loginStatusMessage = "You must select an Avatar image"
            return
        }
        
        FirebaseManager.shared.auth.createUser(withEmail: emailAddress, password: emailPassword) { result, err in
            if let err = err {
                print("Failed to create user:", err)
                self.loginStatusMessage = "Failed to create user: \(err)"
                return
            }
            print("Successfully created user: \(result?.user.uid ?? "")")
            self.loginStatusMessage = "Successfully created user: \(result?.user.uid ?? "")"
            
            self.persistImageToStorage()
        }
    }
    
    private func persistImageToStorage() {
        //        let filename = UUID().uuidString
        guard let uid = FirebaseManager.shared.auth.currentUser?.uid
        else {return}
        let ref = FirebaseManager.shared.storage.reference(withPath: uid)
        guard let imageData = self.userImage?.jpegData(compressionQuality: 0.5) else {return}
        
        ref.putData(imageData, metadata: nil) { metadata, err in
            if let err = err {
                self.loginStatusMessage = "Failed to push image to Storage: \(err)"
                return
            }
            
            ref.downloadURL { url, err in
                if let err = err {
                    self.loginStatusMessage = "Failed to retrieve downloadURL: \(err)"
                    return
                }
                self.loginStatusMessage = "Successfully stored image with url: \(url?.absoluteString ?? "")"
                
                //store user information
                //unwrapping first since optional
                guard let url = url else {return}
                self.storeUserInformation(imageProfileUrl: url)
            }
        }
        
    }
    
    private func storeUserInformation(imageProfileUrl: URL) {
        guard let uid = FirebaseManager.shared.auth.currentUser?.uid else { return }
        let userData = [FirebaseConstants.email: self.emailAddress, FirebaseConstants.uid: uid, FirebaseConstants.profileImageUrl: imageProfileUrl.absoluteString]
        FirebaseManager.shared.firestore.collection(FirebaseConstants.users)
            .document(uid).setData(userData) { err in
                if let err = err {
                    print(err)
                    self.loginStatusMessage = "\(err)"
                    return
                }

                print("Success")

                self.didCompleteLoginProcess()
            }
    }
    
// For preview sake removing validation
    func textFieldValidatorEmail(_ string: String) -> Bool {
//        if string.count > 100 {
//            return false
//        }
//        let emailFormat = "(?:[\\p{L}0-9!#$%\\&'*+/=?\\^_`{|}~-]+(?:\\.[\\p{L}0-9!#$%\\&'*+/=?\\^_`{|}" + "~-]+)*|\"(?:[\\x01-\\x08\\x0b\\x0c\\x0e-\\x1f\\x21\\x23-\\x5b\\x5d-\\" + "x7f]|\\\\[\\x01-\\x09\\x0b\\x0c\\x0e-\\x7f])*\")@(?:(?:[\\p{L}0-9](?:[a-" + "z0-9-]*[\\p{L}0-9])?\\.)+[\\p{L}0-9](?:[\\p{L}0-9-]*[\\p{L}0-9])?|\\[(?:(?:25[0-5" + "]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-" + "9][0-9]?|[\\p{L}0-9-]*[\\p{L}0-9]:(?:[\\x01-\\x08\\x0b\\x0c\\x0e-\\x1f\\x21" + "-\\x5a\\x53-\\x7f]|\\\\[\\x01-\\x09\\x0b\\x0c\\x0e-\\x7f])+)\\])"
//        //let emailFormat = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
//        let emailPredicate = NSPredicate(format:"SELF MATCHES %@", emailFormat)
//        return emailPredicate.evaluate(with: string)
        
        return true
    }
}

#Preview {
    LoginView(didCompleteLoginProcess: {
        
    })
}
