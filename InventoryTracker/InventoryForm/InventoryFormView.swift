//
//  InventoryFormView.swift
//  InventoryTracker
//
//  Created by dgsw8th71 on 2/18/24.
//

import SwiftUI
import UniformTypeIdentifiers
import SafariServices

struct InventoryFormView: View {
    
    @Bindable var vm = InventoryFormVM()
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        Form {
            List {
                inputSection
                arSection
                
                if case .deleting(let type) = vm.loadingState {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            ProgressView()
                            Text("Deleting \(type == .usdzWithThumbnail ? "USDZ file" : "Item")")
                                .foregroundStyle(.red)
                        }
                        Spacer()
                    }
                }
                
                if case .edit = vm.formType {
                    Button("Delete", role: .destructive) {
                        Task {
                            do {
                                try await vm.deleteItem()
                                dismiss()
                            } catch {
                                vm.error = error.localizedDescription
                            }
                        }
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
                .disabled(vm.loadingState != .none)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    do {
                        try vm.save()
                        dismiss()
                    } catch {}
                }
                .disabled(vm.loadingState != .none || vm.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .confirmationDialog("Add USDZ", isPresented: $vm.showUSDZSource) {
            Button("Select file") {
                vm.selectedUSDZSource = .fileImporter
            }
            Button("Object Capture") {
                vm.selectedUSDZSource = .objectCapture
            }
        }
        .fileImporter(isPresented: .init(get: { vm.selectedUSDZSource == .fileImporter },
                                         set: { _ in vm.selectedUSDZSource = nil }),
                      allowedContentTypes: [UTType.usdz], 
                      onCompletion: { result in
            switch result {
                
            case .success(let url):
                print("success")
                Task {
                    await vm.uploadUSDZ(fileURL: url, isSecurityScopedResource: true)
                }
            case .failure(let failure):
                print(failure)
                vm.error = failure.localizedDescription
            }
        })
        .alert(isPresented: .init(get: { vm.error != nil }, set: { _ in vm.error = nil }), error: "에러 생김") { _ in
            
        } message: { _ in
            Text(vm.error ?? "")
        }
        .navigationTitle(vm.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    var inputSection: some View {
        Section {
            TextField("Name", text: $vm.name)
            Stepper("Quantity: \(vm.quantity)", value: $vm.quantity)
        }
        .disabled(vm.loadingState != .none)
    }
    
    var arSection: some View {
        Section("AR Model") {
            if let thumbnailURL = vm.thumbnailURL {
                AsyncImage(url: thumbnailURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity, maxHeight: 300)
                    case .failure:
                        Text("썸네일 불러오기 실패")
                    default:
                        ProgressView()
                    }
                }
                .onTapGesture {
                    guard let usdzURL = vm.usdzURL else { return }
                    viewAR(url: usdzURL)
                }
            }
            if let usdzURL = vm.usdzURL {
                Button {
                    viewAR(url: usdzURL)
                } label: {
                    HStack {
                        Image(systemName: "arkit")
                            .imageScale(.large)
                        Text("View")
                    }
                }
                
                Button("Delete USDZ", role: .destructive) {
                    Task {
                        await vm.deleteUSDZ()
                    }
                }
            } else {
                Button {
                    vm.showUSDZSource = true
                } label: {
                    HStack {
                        Image(systemName: "arkit")
                            .imageScale(.large)
                        Text("Add USDZ")
                    }
                }
            }
            
            if let progress = vm.uploadProgress,
               case let .uploading(type) = vm.loadingState,
               progress.totalUnitCount > 0 {
                VStack {
                    ProgressView(value: progress.fractionCompleted) {
                        Text("Uploading \(type == .usdz ? "USDZ" : "Thumbnail") file \(Int(progress.fractionCompleted * 100))%")
                    }
                    Text("\(vm.byteCountFormatter.string(fromByteCount: progress.completeUnitCount)) / \(vm.byteCountFormatter.string(fromByteCount: progress.totalUnitCount))")
                }
            }
        }
        .disabled(vm.loadingState != .none)
    }
    
    func viewAR(url: URL) {
        let safariVC = SFSafariViewController(url: url)
        let vc = UIApplication.shared.firstKeyWindow?.rootViewController?.presentedViewController ?? UIApplication.shared.firstKeyWindow?.rootViewController
        vc?.present(safariVC, animated: true)
    }
}

extension UIApplication {
    
    var firstKeyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }
            .first?.keyWindow
    }
    
}

#Preview {
    NavigationStack {
        InventoryFormView()
    }
}
