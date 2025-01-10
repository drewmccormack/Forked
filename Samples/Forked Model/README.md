
# Sample: Forked Model

This sample demonstrates how to use the `ForkedModel` package to setup a simple, mergeable model. 

In `Store`, it setups up a `ForkedResource` with two branches, representing two different parts of the app UI, which need to sync up occasionally.

In the UI, you can edit text in one of two places, and you can also set a counter. When you click the "Everywhere" button, the `ForkedResource` is merged, which in turn does a property-wise merge of the model.

Notable is that the text in the model is labeled with `@Merged`. By default, a `String` variable which has this annotation will use an advanced merging strategy that can merge changes to the same part of the string, similar to how you would do it in a collaborative editing app. You should find that if you make changes to each text view, and then press the button, the final text should be a reasonable merge of the two, even if the changes overlap.
