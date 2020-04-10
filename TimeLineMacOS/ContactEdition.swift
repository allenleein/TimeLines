//
//  ContactEdition.swift
//  TimeLineMacOS
//
//  Created by Mathieu Dutour on 08/04/2020.
//  Copyright © 2020 Mathieu Dutour. All rights reserved.
//

import SwiftUI
import TimeLineSharedMacOS
import MapKit
import CoreLocation

struct ButtonThatLookLikeTextFieldStyle: ButtonStyle {
  var locationText: String

  func makeBody(configuration: Self.Configuration) -> some View {
    configuration.label
      .font(.headline)
      .padding(10)
      .foregroundColor(Color(self.locationText == "" ? NSColor.placeholderTextColor : NSColor.labelColor))
      .background(Color(NSColor.controlBackgroundColor))
      .border(Color(NSColor.controlShadowColor), width: 0.5)
  }
}

struct ContactEdition: View {
  @Environment(\.presentationMode) var presentationMode

  @Binding var contact: Contact?

  @State private var contactName: String
  @State private var locationText = ""
  @State private var location: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 0, longitude: 0)
  @State private var showModal = false

  @State private var timezone: TimeZone?

  @State private var locationCompletion: MKLocalSearchCompletion?

  init(contact: Binding<Contact?>) {
    self._contact = contact
    _contactName = State(initialValue: contact.wrappedValue?.name ?? "")
    _locationText = State(initialValue: contact.wrappedValue?.locationName ?? "")
    _location = State(initialValue: contact.wrappedValue?.location ?? CLLocationCoordinate2D(latitude: 0, longitude: 0))
    _timezone = State(initialValue: contact.wrappedValue?.timeZone)
  }

  var body: some View {
    VStack {
      Spacer()
      VStack(alignment: .leading) {
        HStack {
          Text("Name")
            .font(.title)
          TextField("Jane Doe", text: $contactName)
            .font(.title)
            .multilineTextAlignment(.trailing)
            .frame(alignment: .trailing)
        }

        HStack {
          Text("Location")
            .font(.title)

          GeometryReader { p in
            Button(action: {
              self.showModal = true
            }) {
              Text(self.locationText == "" ? "San Francisco" : self.locationText)
                .multilineTextAlignment(.trailing)
                .font(.title)
                .frame(width: p.size.width - 20, height: 22, alignment: .trailing)
                .foregroundColor(Color(self.locationText == "" ? NSColor.placeholderTextColor : NSColor.labelColor))
            }
            .frame(height: 22, alignment: .trailing)
            .buttonStyle(ButtonThatLookLikeTextFieldStyle(locationText: self.locationText))
            .sheet(isPresented: self.$showModal) {
              SearchController(resultView: { mapItem in
                Button(action: {
                  self.locationCompletion = mapItem
                  self.locationText = mapItem.title
                  self.showModal = false
                }) {
                  Text(mapItem.title)
                }
                .buttonStyle(ButtonThatLookLikeRowStyle())
              })
            }
          }.frame(height: 30)

        }
        HStack {
          Spacer()
          Button(action: {
            self.save()
          }) {
            Text("Save")
          }
          .padding(.top)
          .disabled(contactName == "" || locationText == "")
        }
        Spacer()
      }
      .padding()

      Spacer()
    }
  }

  func save() {
    if let locationCompletion = locationCompletion, locationCompletion.title != contact?.locationName {
      // need to fetch the new location
      let request = MKLocalSearch.Request(completion: locationCompletion)
      request.resultTypes = .address
      let search = MKLocalSearch(request: request)
      search.start { response, _ in
        guard let response = response, let mapItem = response.mapItems.first else {
          return
        }
        self.timezone = mapItem.timeZone
        self.location = mapItem.placemark.location?.coordinate ?? CLLocationCoordinate2D(latitude: 0, longitude: 0)
        self.updateContact()
      }
    } else if contactName != contact?.name {
      self.updateContact()
    }
  }

  func updateContact() {
    if let contact = contact {
      contact.name = contactName
      contact.latitude = location.latitude
      contact.longitude = location.longitude
      contact.locationName = locationText
      contact.timezone = Int16(timezone?.secondsFromGMT() ?? 0)
      CoreDataManager.shared.saveContext()
    } else {
      contact = CoreDataManager.shared.createContact(
        name: contactName,
        latitude: location.latitude,
        longitude: location.longitude,
        locationName: locationText,
        timezone: Int16(timezone?.secondsFromGMT() ?? 0)
      )
    }
  }
}

struct ContactEdition_Previews: PreviewProvider {

  static var previews: some View {
    var contact: Contact? = nil
    return ContactEdition(contact: Binding(get: { contact }, set: { new in contact = new }))
  }
}

